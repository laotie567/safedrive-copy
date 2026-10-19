import Foundation

// 统一日志：写入 ~/Library/Logs/硬盘复制助手.log，便于事后定位问题
// （控制台输出保留，便于终端里直接跑 --selftest 时观察）

enum Log {

    static let fileURL: URL = {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("硬盘复制助手.log")
    }()

    private static let lock = NSLock()
    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss.SSS"
        return f
    }()

    /// 启动时调用：超过 2MB 则只保留末尾 512KB，避免日志无限增长
    static func startSession() {
        lock.lock(); defer { lock.unlock() }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int, size > 2 * 1024 * 1024 {
            if let data = try? Data(contentsOf: fileURL), data.count > 512 * 1024 {
                try? data.suffix(512 * 1024).write(to: fileURL)
            }
        }
        append("════════ 启动 session（pid \(ProcessInfo.processInfo.processIdentifier)）════════")
    }

    static func write(_ message: String, file: String = #fileID, line: Int = #line) {
        lock.lock(); defer { lock.unlock() }
        let fn = file.split(separator: "/").last.map(String.init) ?? file
        append("[\(df.string(from: Date()))] [\(fn):\(line)] \(message)")
    }

    // 调用方已持锁
    private static func append(_ line: String) {
        let text = line + "\n"
        if let h = try? FileHandle(forWritingTo: fileURL) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            _ = try? h.write(contentsOf: Data(text.utf8))
        } else {
            try? Data(text.utf8).write(to: fileURL)
        }
        FileHandle.standardError.write(Data(text.utf8))
    }
}
