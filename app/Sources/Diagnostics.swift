import Foundation

// 环境自检：把「目标盘 / 权限 / 挂载」一次性查清，用户可一键复制反馈
enum Diagnostics {

    static func report(target: URL) -> String {
        let fm = FileManager.default
        var L: [String] = []
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        L.append("时间：\(f.string(from: Date()))")
        L.append("App 路径：\(Bundle.main.bundlePath)")
        L.append("BundleID：\(Bundle.main.bundleIdentifier ?? "?")")
        L.append("目标路径：\(target.path)")
        L.append("目标可达：\(((try? target.checkResourceIsReachable()) ?? false) ? "是" : "否")")
        L.append("目标可写：\(fm.isWritableFile(atPath: target.path) ? "是" : "否")")
        if let ro = try? target.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly {
            L.append("卷只读：\(ro ? "是" : "否")")
        }
        L.append("")
        L.append("── 文件夹访问自检（列目录）──")
        for (name, path) in [("桌面", "Desktop"), ("下载", "Downloads"), ("文稿", "Documents")] {
            let p = NSHomeDirectory() + "/" + path
            L.append("\(name)：\(canList(p) ? "可访问" : "被系统拒绝")")
        }
        L.append("")
        L.append("── 已挂载卷 ──")
        for vol in VolumeLocator.mountedVolumes() {
            let name = VolumeLocator.displayName(vol)
            let kind = VolumeLocator.isNTFS(vol) ? "NTFS" : "其他"
            let ro = VolumeLocator.isReadOnly(vol) ? "只读" : "可读写"
            L.append("\(name)（\(kind)，\(ro)）：\(vol.path)")
        }
        if VolumeLocator.mountedVolumes().isEmpty { L.append("（无外接卷）") }
        L.append("")
        L.append("── 目标卷挂载信息 ──")
        L.append(VolumeLocator.mountLine(for: target) ?? "（未找到目标卷的挂载信息）")
        L.append("")
        L.append("── 系统 ──")
        let v = ProcessInfo.processInfo.operatingSystemVersion
        L.append("macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)")
        L.append("用户：\(NSUserName())")
        return L.joined(separator: "\n")
    }

    static func canList(_ path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        return (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil
    }
}
