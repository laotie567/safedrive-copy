import Foundation
func fmtBytes(_ n: Int64) -> String {
    let d = Double(n)
    if d < 1024 { return "\(n) B" }
    if d < 1048576 { return String(format: "%.0f KB", d / 1024) }
    if d < 1073741824 { return String(format: "%.1f MB", d / 1048576) }
    if d < 1099511627776 { return String(format: "%.1f GB", d / 1073741824) }
    return String(format: "%.1f TB", d / 1099511627776)
}
