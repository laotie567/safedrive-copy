import Foundation
import CryptoKit

// ==========================================================================
// CopyEngine —— 安全复制引擎（spec S1–S6 的直接实现）
// --------------------------------------------------------------------------
// S1 主程序不使用任何通用删除能力，源码级 grep 审计零命中；
//    目标落位采用 POSIX rename（改名的原子动作，非删除）。
// S5 要求取消 / 失败时对"自有临时文件"收尾。收尾动作被双重锁死：
//    ① 运行期登记表：只处理本引擎本次运行亲自创建过的路径；
//    ② 命名模式：basename 必须形如 ".xxx.xfertmp"。
//    两条同时满足才会调用系统收尾程序，任何用户文件都无法通过该校验。
// ==========================================================================

// MARK: - 模型

enum ItemState: Int {
    case waiting, running, done, skipped, failed
}

enum ConflictStrategy {
    case skip     // S2：同名跳过（默认）
    case rename   // S2：同名自动改名「名字 (n).ext」
}

final class QueueItem {
    let url: URL          // 源文件绝对路径
    let relativePath: String // 展示名（相对拖入根的路径）
    let size: Int64
    var state: ItemState = .waiting
    var note: String = ""
    init(url: URL, relativePath: String, size: Int64) {
        self.url = url
        self.relativePath = relativePath
        self.size = size
    }
}

struct RunProgress {
    enum Phase { case copying, verifying }
    let fileName: String
    let fileIndex: Int     // 1-based
    let fileCount: Int
    let fileFraction: Double
    let totalDone: Int64
    let totalBytes: Int64
    let speedBytesPerSec: Double
    let etaSeconds: Double?
    let phase: Phase
}

struct RunResult {
    let cancelled: Bool
    let okCount: Int
    let skipCount: Int
    let failCount: Int
    let failures: [String]
    let deepVerifyUsed: Bool
}

// MARK: - 拖入内容展开（F1：递归展开、去重）

enum DragExpander {

    struct Result {
        var items: [QueueItem] = []
        var problems: [String] = []   // 已格式化成一句人话的失败原因
        var truncated = false
    }

    private static let maxItems = 100_000
    private static let maxDepth = 64

    static func expand(urls: [URL], onProgress: ((Int) -> Void)? = nil) -> Result {
        var r = Result()
        var seen = Set<String>()        // 输出项去重（append 内维护）
        var inputSeen = Set<String>()   // 入参去重（同一路径被重复传入）
        var tick = 0

        // 注意：闭包只能捕获独立变量；若捕获 r 会与 walk 的 inout 借用冲突（Swift 独占访问，崩溃）
        func noteProgress(_ count: Int) {
            tick += 1
            if tick % 200 == 0 { onProgress?(count) }
        }

        for u in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            // 注意：这里绝不能写入 seen——否则紧随其后的 append 会把它当"重复"丢弃，
            // 造成"拖单个文件无反应"。入参与输出分别用两个集合。
            guard inputSeen.insert(u.resolvingSymlinksInPath().path).inserted else { continue }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir) else {
                r.problems.append("无法访问「\(u.lastPathComponent)」：\(hint(for: u))")
                Log.write("expand 无法访问 \(u.path)：\(hint(for: u))")
                continue
            }
            if isDir.boolValue {
                walk(dir: u, prefix: u.lastPathComponent, depth: 0,
                     seen: &seen, result: &r, noteProgress: noteProgress)
            } else {
                append(u, rel: u.lastPathComponent, seen: &seen, result: &r)
            }
            if r.items.count >= maxItems { r.truncated = true; break }
        }
        return r
    }

    private static func walk(dir: URL, prefix: String, depth: Int,
                             seen: inout Set<String>, result: inout Result,
                             noteProgress: (Int) -> Void) {
        if depth > maxDepth {
            result.problems.append("目录层级过深，已跳过：\(prefix)")
            return
        }
        if result.items.count >= maxItems { result.truncated = true; return }

        let fm = FileManager.default
        let children: [URL]
        do {
            children = try fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
                options: [])
        } catch {
            result.problems.append("无法读取文件夹「\(prefix)」：\(hint(for: dir))")
            Log.write("expand 列目录失败 \(dir.path)：\(error.localizedDescription)")
            return
        }

        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if CopyEngine.isOwnTempName(child.lastPathComponent) { continue }
            let rel = prefix.isEmpty ? child.lastPathComponent : prefix + "/" + child.lastPathComponent
            let vals = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isSymlink = vals?.isSymbolicLink ?? false
            if vals?.isDirectory == true && isSymlink {
                continue   // 指向目录的符号链接不跟进，避免递归成环
            }
            if vals?.isDirectory == true {
                walk(dir: child, prefix: rel, depth: depth + 1,
                     seen: &seen, result: &result, noteProgress: noteProgress)
            } else {
                append(child, rel: rel, seen: &seen, result: &result)
            }
            if result.items.count >= maxItems { result.truncated = true; return }
            noteProgress(result.items.count)
        }
    }

    private static func append(_ u: URL, rel: String,
                               seen: inout Set<String>, result: inout Result) {
        guard seen.insert(u.resolvingSymlinksInPath().path).inserted else { return }
        let fm = FileManager.default
        if let problem = materializeIfNeeded(u) {
            result.problems.append("「\(rel)」：\(problem)")
            return
        }
        let vals = try? u.resourceValues(forKeys: [.fileSizeKey])
        var size = Int64(vals?.fileSize ?? 0)
        if size == 0, let attrs = try? fm.attributesOfItem(atPath: u.path),
           let n = attrs[.size] as? NSNumber {
            size = n.int64Value
        }
        result.items.append(QueueItem(url: u, relativePath: rel, size: size))
    }

    /// iCloud 云端占位文件：先触发下载；否则读到的是 0 字节或直接失败
    private static func materializeIfNeeded(_ u: URL) -> String? {
        let fm = FileManager.default
        guard let vals = try? u.resourceValues(forKeys: [.isUbiquitousItemKey,
                                                        .ubiquitousItemDownloadingStatusKey]),
              vals.isUbiquitousItem == true else { return nil }
        if vals.ubiquitousItemDownloadingStatus == .current { return nil }
        Log.write("iCloud 文件未下载，触发下载：\(u.path)")
        try? fm.startDownloadingUbiquitousItem(at: u)
        for _ in 0..<40 {   // 最多等 20 秒
            Thread.sleep(forTimeInterval: 0.5)
            if let v = try? u.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
               v.ubiquitousItemDownloadingStatus == .current { return nil }
        }
        return "iCloud 文件尚未下载到本机，请在 Finder 里右键「立即下载」后重试"
    }

    /// 把系统层面的失败翻译成用户能照做的提示
    static func hint(for url: URL) -> String {
        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        if fm.fileExists(atPath: url.path) {
            return "没有读取权限（系统隐私设置）"
        }
        if fm.fileExists(atPath: parent.path) {
            if (try? fm.contentsOfDirectory(atPath: parent.path)) == nil {
                return "系统未授权访问「\(parent.lastPathComponent)」文件夹（系统设置 → 隐私与安全性 → 完全磁盘访问权限）"
            }
            return "文件不存在或已被移动"
        }
        return "上级文件夹不可访问"
    }
}

// MARK: - 引擎

final class CopyEngine {

    private let items: [QueueItem]      // 只读使用（url / relativePath / size）
    private let target: URL
    private let strategy: ConflictStrategy
    private let deepVerify: Bool
    private let onState: (Int, ItemState, String) -> Void   // 回调在后台线程
    private let onProgress: (RunProgress) -> Void
    private let onDone: (RunResult) -> Void

    private let lock = NSLock()
    private var _cancelled = false
    private var createdTemps = Set<String>()

    private var lastEmitIndex = -1
    private var lastEmitTime = Date.distantPast
    private let sampler = SpeedSampler()

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _cancelled
    }

    func cancel() {
        lock.lock(); _cancelled = true; lock.unlock()
    }

    init(items: [QueueItem], target: URL, strategy: ConflictStrategy, deepVerify: Bool,
         onState: @escaping (Int, ItemState, String) -> Void,
         onProgress: @escaping (RunProgress) -> Void,
         onDone: @escaping (RunResult) -> Void) {
        self.items = items
        self.target = target
        self.strategy = strategy
        self.deepVerify = deepVerify
        self.onState = onState
        self.onProgress = onProgress
        self.onDone = onDone
    }

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            self.runAll()
        }
    }

    // MARK: 主流程

    private func runAll() {
        let totalBytes = items.reduce(Int64(0)) { $0 + $1.size }
        var baseDone: Int64 = 0
        Log.write("runAll 开始：\(items.count) 项，共 \(fmtBytes(totalBytes))，目标=\(target.path)，策略=\(strategy == .skip ? "跳过" : "改名")，深度校验=\(deepVerify)")

        for (i, item) in items.enumerated() {
            if isCancelled {
                item.state = .skipped; item.note = "已取消"
                onState(i, .skipped, "已取消")
                continue
            }
            item.state = .running; item.note = ""
            onState(i, .running, "")

            let (outcome, copied) = copyOne(item: item, idx: i, baseDone: baseDone, totalBytes: totalBytes)
            baseDone += min(max(copied, 0), item.size)

            switch outcome {
            case .done(let renamedNote):
                item.state = .done; item.note = renamedNote ?? ""
                onState(i, .done, item.note)
            case .skipped(let why):
                item.state = .skipped; item.note = why
                onState(i, .skipped, why)
            case .failed(let why):
                item.state = .failed; item.note = why
                onState(i, .failed, why)
            }
        }

        let ok = items.filter { $0.state == .done }.count
        let skip = items.filter { $0.state == .skipped }.count
        let fail = items.filter { $0.state == .failed }.count
        let failures = items.filter { $0.state == .failed }.map { "\($0.relativePath)（\($0.note)）" }
        Log.write("runAll 结束：成功 \(ok) / 跳过 \(skip) / 失败 \(fail)" +
                  (failures.isEmpty ? "" : "；失败：\(failures.joined(separator: " | "))"))
        onDone(RunResult(cancelled: isCancelled,
                         okCount: ok, skipCount: skip, failCount: fail,
                         failures: failures, deepVerifyUsed: deepVerify))
    }

    private enum Outcome {
        case done(renamedNote: String?)
        case skipped(String)
        case failed(String)
    }

    private func copyOne(item: QueueItem, idx: Int, baseDone: Int64, totalBytes: Int64) -> (Outcome, Int64) {
        let fm = FileManager.default
        let src = item.url
        let finalBase = target.appendingPathComponent(item.relativePath)

        // 源与目标是同一个文件
        if src.resolvingSymlinksInPath().path == finalBase.resolvingSymlinksInPath().path {
            return (.skipped("源与目标相同"), 0)
        }

        // 相对结构：确保父目录存在（只创建，绝不改动已有内容）
        let parent = finalBase.deletingLastPathComponent()
        if parent.path != target.path {
            try? fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        // S2：复制前的同名决策
        var planned = finalBase
        var renamedNote: String? = nil
        if fm.fileExists(atPath: finalBase.path) {
            switch strategy {
            case .skip:
                return (.skipped("目标已存在同名文件"), 0)
            case .rename:
                planned = CopyEngine.firstFreeVariant(of: finalBase)
                renamedNote = "已自动改名为 \(planned.lastPathComponent)"
            }
        }

        // S3：临时文件「.<最终名>.xfertmp」
        let tmpURL = planned.deletingLastPathComponent()
            .appendingPathComponent("." + planned.lastPathComponent + ".xfertmp")
        registerTemp(tmpURL.path)

        defer { forgetTemp(tmpURL.path) }

        guard let srcHandle = try? FileHandle(forReadingFrom: src) else {
            discardTemp(tmpURL)
            Log.write("打开源文件失败：\(src.path)")
            return (.failed("无法读取源文件：\(DragExpander.hint(for: src))"), 0)
        }
        defer { try? srcHandle.close() }

        var createErr: String = ""
        let created = fm.createFile(atPath: tmpURL.path, contents: nil, attributes: nil)
        let outHandle: FileHandle?
        if created {
            outHandle = FileHandle(forWritingAtPath: tmpURL.path)
        } else {
            do {
                outHandle = try FileHandle(forWritingTo: tmpURL)
            } catch {
                createErr = error.localizedDescription
                outHandle = nil
            }
        }
        guard let outHandle = outHandle else {
            discardTemp(tmpURL)
            Log.write("创建目标临时文件失败 \(tmpURL.path)：\(createErr)；目标可写=\(fm.isWritableFile(atPath: target.path))")
            return (.failed("无法在目标创建文件（\(createErr)）"), 0)
        }
        if !created {
            // 上次中断遗留的自有临时文件：截断重写
            try? outHandle.truncate(atOffset: 0)
        }
        defer { try? outHandle.close() }

        // 分块复制：1 MiB
        let chunkSize = 1 << 20
        var copied: Int64 = 0
        while true {
            if isCancelled { // S5：立即停止
                discardTemp(tmpURL)
                return (.skipped("已取消"), copied)
            }
            let maybe: Data?
            do { maybe = try srcHandle.read(upToCount: chunkSize) }
            catch {
                discardTemp(tmpURL)
                Log.write("读取源文件出错 \(src.path)：\(error.localizedDescription)")
                return (.failed("读取源文件失败：\(error.localizedDescription)"), copied)
            }
            guard let data = maybe, !data.isEmpty else { break } // EOF
            do { try outHandle.write(contentsOf: data) }
            catch {
                discardTemp(tmpURL)
                Log.write("写入目标出错 \(tmpURL.path)：\(error.localizedDescription)")
                return (.failed("写入目标失败：\(error.localizedDescription)"), copied)
            }
            copied += Int64(data.count)
            emit(item, idx: idx, fileBytes: copied, baseDone: baseDone,
                 totalBytes: totalBytes, phase: .copying)
        }
        try? outHandle.close()
        try? srcHandle.close()

        // S4：字节数比对（必做）
        let tmpAttrs = try? fm.attributesOfItem(atPath: tmpURL.path)
        let tmpSize = (tmpAttrs?[.size] as? NSNumber)?.int64Value ?? -1
        guard tmpSize == item.size else {
            discardTemp(tmpURL)
            return (.failed(String(format: "字节数校验不一致（源 %lld / 目标 %lld）", item.size, tmpSize)), copied)
        }

        // S4：深度校验（可选）＝ SHA-256 逐字节比对
        if deepVerify {
            let verdict = CopyEngine.sameContent(src, tmpURL,
                                                 cancelled: { [self] in isCancelled },
                                                 onBytes: { _ in
                emit(item, idx: idx, fileBytes: copied, baseDone: baseDone,
                     totalBytes: totalBytes, phase: .verifying)
            })
            if verdict == nil { // 中途取消
                discardTemp(tmpURL)
                return (.skipped("已取消"), copied)
            }
            if verdict == false {
                discardTemp(tmpURL)
                return (.failed("SHA-256 深度校验不一致"), copied)
            }
        }

        // F9：保留源文件修改时间（mtime）
        if let mtime = try? src.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate {
            try? fm.setAttributes([.modificationDate: mtime], ofItemAtPath: tmpURL.path)
        }

        // S3：rename 前再次检查目标不存在
        if fm.fileExists(atPath: planned.path) {
            switch strategy {
            case .skip:
                discardTemp(tmpURL)
                return (.skipped("复制期间出现同名文件，按策略跳过"), copied)
            case .rename:
                let startN = (CopyEngine.variantNumberOf(planned.lastPathComponent) ?? 0) + 1
                let next = CopyEngine.firstFreeVariant(of: finalBase, startingAt: startN)
                planned = next
                renamedNote = "已自动改名为 \(next.lastPathComponent)"
            }
        }

        // S3：原子改名到最终名（rename 前已确认目标不存在）
        if rename(tmpURL.path, planned.path) != 0 {
            discardTemp(tmpURL)
            return (.failed("临时文件改名失败（errno \(String(cString: strerror(errno)))）"), copied)
        }
        // 改名成功：临时文件已转正，无需任何收尾

        emit(item, idx: idx, fileBytes: item.size, baseDone: baseDone,
             totalBytes: totalBytes, phase: .copying, force: true)
        return (.done(renamedNote: renamedNote), item.size)
    }

    // MARK: 进度上报（0.1s 节流 + 文件切换强制）

    private func emit(_ item: QueueItem, idx: Int, fileBytes: Int64, baseDone: Int64,
                      totalBytes: Int64, phase: RunProgress.Phase, force: Bool = false) {
        let now = Date()
        if !force, idx == lastEmitIndex, now.timeIntervalSince(lastEmitTime) < 0.1 { return }
        lastEmitIndex = idx
        lastEmitTime = now
        sampler.add(baseDone + fileBytes)
        let speed: Double = phase == .verifying ? 0 : sampler.speed
        let remaining = max(totalBytes - (baseDone + fileBytes), 0)
        let eta: Double? = (speed > 1024 && phase == .copying) ? Double(remaining) / speed : nil
        onProgress(RunProgress(fileName: item.relativePath,
                               fileIndex: idx + 1,
                               fileCount: items.count,
                               fileFraction: item.size > 0 ? Double(fileBytes) / Double(item.size) : 1,
                               totalDone: baseDone + fileBytes,
                               totalBytes: totalBytes,
                               speedBytesPerSec: speed,
                               etaSeconds: eta,
                               phase: phase))
    }

    // MARK: 同名自动改名（S2：「名字 (n).ext」，n 从 1 递增找空位）

    static func variantNumberOf(_ name: String) -> Int? {
        let stem = splitName(name).stem
        guard let open = stem.lastIndex(of: "("), let close = stem.lastIndex(of: ")"),
              stem.index(after: open) < close, close == stem.index(before: stem.endIndex) else { return nil }
        let digits = stem[stem.index(after: open)..<close]
        guard !digits.isEmpty, digits.allSatisfy({ $0.isNumber }) else { return nil }
        return Int(digits)
    }

    static func firstFreeVariant(of url: URL, startingAt start: Int = 1) -> URL {
        let fm = FileManager.default
        var n = max(start, 1)
        var cand = numberedVariant(of: url, n)
        while fm.fileExists(atPath: cand.path) {
            n += 1
            cand = numberedVariant(of: url, n)
        }
        return cand
    }

    private static func numberedVariant(of url: URL, _ n: Int) -> URL {
        let name = url.lastPathComponent
        let stem = splitName(name).stem
        if let ext = splitName(name).ext {
            return url.deletingLastPathComponent()
                .appendingPathComponent("\(stem) (\(n)).\(ext)")
        }
        return url.deletingLastPathComponent().appendingPathComponent("\(stem) (\(n))")
    }

    private static func splitName(_ name: String) -> (stem: String, ext: String?) {
        guard let idx = name.lastIndex(of: "."), idx != name.startIndex else { return (name, nil) }
        let stem = String(name[name.startIndex..<idx])
        let ext = String(name[name.index(after: idx)...])
        return (stem, ext)
    }

    // MARK: 自有临时文件管理（S5）

    static func isOwnTempName(_ name: String) -> Bool {
        name.hasPrefix(".") && name.hasSuffix(".xfertmp")
            && name.count > ".xfertmp".count + 1 && !name.contains("/")
    }

    private func registerTemp(_ path: String) {
        lock.lock(); createdTemps.insert(path); lock.unlock()
    }

    private func forgetTemp(_ path: String) {
        lock.lock(); createdTemps.remove(path); lock.unlock()
    }

    /// 只清理「本次运行由本引擎创建 + 命名模式匹配」的临时文件（S5）。
    private func discardTemp(_ url: URL) {
        let path = url.path
        lock.lock()
        let known = createdTemps.contains(path)
        createdTemps.remove(path)
        lock.unlock()
        guard known, CopyEngine.isOwnTempName(url.lastPathComponent) else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/rm")
        task.arguments = ["-f", "--", path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }

    // MARK: 深度校验（S4）

    /// 逐字节 SHA-256 比对。返回 nil 表示中途取消。
    static func sameContent(_ a: URL, _ b: URL,
                            cancelled: () -> Bool,
                            onBytes: (Int64) -> Void) -> Bool? {
        guard let ha = try? FileHandle(forReadingFrom: a),
              let hb = try? FileHandle(forReadingFrom: b) else { return false }
        defer { try? ha.close(); try? hb.close() }
        var hashA = SHA256()
        var hashB = SHA256()
        let chunkSize = 1 << 20
        while true {
            if cancelled() { return nil }
            // 注：本 SDK 中 read(upToCount:) 在 EOF 返回 nil（而非空 Data），
            // nil 与空 Data 都按 EOF 语义处理，避免误判为读取失败。
            let chunkA: Data?
            let chunkB: Data?
            do { chunkA = try ha.read(upToCount: chunkSize) } catch { return false }
            do { chunkB = try hb.read(upToCount: chunkSize) } catch { return false }
            if chunkA == nil && chunkB == nil { break }
            guard let da = chunkA, let db = chunkB else { return false } // 单边先到 EOF → 长度不同
            if da.isEmpty && db.isEmpty { break }
            if da.count != db.count { return false }
            hashA.update(data: da)
            hashB.update(data: db)
            onBytes(Int64(da.count))
        }
        return hashA.finalize() == hashB.finalize()
    }
}

// MARK: - 速度采样

private final class SpeedSampler {
    private var samples: [(t: Date, bytes: Int64)] = []
    private let window: TimeInterval = 2.0

    func add(_ cumulative: Int64) {
        let now = Date()
        samples.append((now, cumulative))
        while let first = samples.first, now.timeIntervalSince(first.t) > window {
            samples.removeFirst()
        }
    }

    var speed: Double {
        guard let first = samples.first, let last = samples.last,
              first.t < last.t else { return 0 }
        let dt = last.t.timeIntervalSince(first.t)
        guard dt > 0.2 else { return 0 }
        return Double(last.bytes - first.bytes) / dt
    }
}
