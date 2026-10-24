import Foundation

// 外接卷识别：不绑定任何特定硬盘名字，自动找出 NTFS / 外接可移动卷。
// 供目标默认值、挂载状态条、环境自检与重挂脚本共用。

enum VolumeLocator {

    /// /Volumes 下所有已挂载的用户卷（排除系统卷、安装镜像、隐藏卷）
    static func mountedVolumes() -> [URL] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: "/Volumes")) ?? []
        return names
            .filter { $0 != "Macintosh HD" && !$0.hasPrefix(".") }
            .map { URL(fileURLWithPath: "/Volumes/" + $0) }
            .filter { url in
                // 排除 dmg 安装镜像（nobrowse）与只读系统映像
                guard let line = mountLine(for: url) else { return false }
                return !line.contains("nobrowse")
            }
    }

    static func isReadOnly(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) ?? false
    }

    static func exists(_ url: URL) -> Bool {
        (try? url.checkResourceIsReachable()) == true
    }

    /// 是否 NTFS 卷：先看系统给出的格式描述，再回退到 mount 输出
    static func isNTFS(_ url: URL) -> Bool {
        if let d = try? url.resourceValues(forKeys: [.volumeLocalizedFormatDescriptionKey])
            .volumeLocalizedFormatDescription, d.uppercased().contains("NTFS") {
            return true
        }
        guard let line = mountLine(for: url) else { return false }
        let lower = line.lowercased()
        return lower.contains("ntfs") || lower.contains("fuse-t")
    }

    /// 卷名（用于界面展示）
    static func displayName(_ url: URL) -> String {
        (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? url.lastPathComponent
    }

    /// 是否为 dmg / 安装镜像等临时挂载卷（不应作为复制目标）
    static func isDiskImage(_ url: URL) -> Bool {
        guard let line = mountLine(for: url) else { return true }
        // 安装镜像通常带 quarantine / nobrowse；退一步：底层不是 /dev/disk 也视为不可用
        if line.contains("quarantine") || line.contains("nobrowse") { return true }
        guard let dev = line.split(separator: " ").first else { return true }
        return !dev.hasPrefix("/dev/disk")
    }

    /// 可作为默认目标的外接卷：必须是真正可写的 NTFS 卷。
    /// 刻意不做「随便挑一个卷」的兜底——选到只读镜像或系统盘会误导用户。
    static func preferredExternalVolume() -> URL? {
        mountedVolumes()
            .filter { !isDiskImage($0) }
            .filter { isNTFS($0) }
            .first { !isReadOnly($0) }
    }

    /// 界面上用于提示的候选卷（含只读的，便于引导用户开启读写）
    static func externalCandidates() -> [URL] {
        mountedVolumes().filter { !isDiskImage($0) && isNTFS($0) }
    }

    /// 一次 mount 调用解析出指定挂载点对应的那一行
    static func mountLine(for url: URL) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/sbin/mount")
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        let target = " on \(url.path) "
        return out.split(separator: "\n").map(String.init)
            .first { $0.contains(target) || $0.hasSuffix(" on \(url.path)") }
    }
}
