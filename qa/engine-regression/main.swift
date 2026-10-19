import Foundation

// 引擎全面回归：单文件 / 文件夹递归 / 多文件 / 同名跳过 / 同名改名 / 大文件 / 只读门
let target = VolumeLocator.preferredExternalVolume() ?? URL(fileURLWithPath: NSTemporaryDirectory())
let fm = FileManager.default
var pass = 0, fail = 0
func ok(_ s: String) { print("✅ \(s)"); pass += 1 }
func bad(_ s: String) { print("❌ \(s)"); fail += 1 }

let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("engine-regress-\(Int(Date().timeIntervalSince1970))")
try! fm.createDirectory(at: base, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: base) }

// 准备样本
let f1 = base.appendingPathComponent("single.txt")
try! "single-file-content".write(to: f1, atomically: true, encoding: .utf8)

let folder = base.appendingPathComponent("folder-sample")
try! fm.createDirectory(at: folder.appendingPathComponent("sub/deep"), withIntermediateDirectories: true)
try! "a".write(to: folder.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
try! "b".write(to: folder.appendingPathComponent("sub/b.txt"), atomically: true, encoding: .utf8)
try! "c".write(to: folder.appendingPathComponent("sub/deep/c.txt"), atomically: true, encoding: .utf8)

let big = base.appendingPathComponent("big.bin")
let bigData = Data(repeating: 0xAB, count: 6 * 1024 * 1024)
try! bigData.write(to: big)

func run(_ items: [QueueItem], strategy: ConflictStrategy, deep: Bool = true) -> (RunResult, [String]) {
    var notes: [String] = []
    let sem = DispatchSemaphore(value: 0)
    var res: RunResult!
    let eng = CopyEngine(items: items, target: target, strategy: strategy, deepVerify: deep,
        onState: { _, _, n in notes.append(n) }, onProgress: { _ in },
        onDone: { r in res = r; sem.signal() })
    eng.start()
    _ = sem.wait(timeout: .now() + 120)
    return (res, notes)
}

// 1. 单文件（本次修复的核心回归）
let r1 = DragExpander.expand(urls: [f1])
r1.items.count == 1 ? ok("单文件展开 1 项") : bad("单文件展开 \(r1.items.count) 项（应为 1）")
let (res1, _) = run(r1.items, strategy: .skip)
res1.okCount == 1 ? ok("单文件复制成功") : bad("单文件复制 ok=\(res1.okCount) fail=\(res1.failCount)")
let dst1 = target.appendingPathComponent("single.txt")
(fm.fileExists(atPath: dst1.path) && (try! Data(contentsOf: dst1)) == (try! Data(contentsOf: f1)))
    ? ok("单文件内容一致") : bad("单文件内容不一致")

// 2. 文件夹递归（保留相对结构）
let r2 = DragExpander.expand(urls: [folder])
r2.items.count == 3 ? ok("文件夹递归展开 3 项") : bad("文件夹展开 \(r2.items.count) 项（应为 3）")
let (res2, _) = run(r2.items, strategy: .skip)
res2.okCount == 3 ? ok("文件夹复制成功 3 项") : bad("文件夹复制 ok=\(res2.okCount) fail=\(res2.failCount) \(res2.failures)")
let deepPath = target.appendingPathComponent("folder-sample/sub/deep/c.txt")
fm.fileExists(atPath: deepPath.path) ? ok("深层目录结构保留") : bad("深层目录结构缺失")

// 3. 多文件混合
let r3 = DragExpander.expand(urls: [f1, big, folder])
r3.items.count == 5 ? ok("多选混合展开 5 项") : bad("多选混合展开 \(r3.items.count) 项（应为 5）")

// 4. 同名跳过（目标已存在）
let (res4, _) = run(r1.items, strategy: .skip)
(res4.skipCount == 1 && res4.okCount == 0) ? ok("同名跳过生效") : bad("同名跳过异常 ok=\(res4.okCount) skip=\(res4.skipCount)")

// 5. 同名自动改名
let (res5, notes5) = run(r1.items, strategy: .rename)
let renamed = target.appendingPathComponent("single (1).txt")
(res5.okCount == 1 && fm.fileExists(atPath: renamed.path))
    ? ok("同名自动改名 → single (1).txt") : bad("改名失败 ok=\(res5.okCount) notes=\(notes5)")

// 6. 大文件（6MB，深度校验）
let r6 = DragExpander.expand(urls: [big])
let (res6, _) = run(r6.items, strategy: .skip)
res6.okCount == 1 ? ok("6MB 大文件复制+SHA256 校验") : bad("大文件复制失败 \(res6.failures)")
let dstBig = target.appendingPathComponent("big.bin")
((try? Data(contentsOf: dstBig))?.count == bigData.count) ? ok("大文件大小一致") : bad("大文件大小不符")

// 7. 不存在路径 → 明确问题说明（不静默）
let ghost = DragExpander.expand(urls: [base.appendingPathComponent("no-such-file.txt")])
(ghost.items.isEmpty && !ghost.problems.isEmpty) ? ok("不存在文件 → 有明确提示") : bad("不存在文件被静默吞掉")

// 清理硬盘上的测试产物
for n in ["single.txt", "single (1).txt", "big.bin"] {
    try? fm.removeItem(at: target.appendingPathComponent(n))
}
try? fm.removeItem(at: target.appendingPathComponent("folder-sample"))

print("\n结果：\(pass) 通过 / \(fail) 失败")
exit(fail == 0 ? 0 : 1)
