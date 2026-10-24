#!/bin/bash
# 在桌面安装两个快捷启动器（可重复运行，覆盖旧的）
#
#   硬盘复制助手.app  — 启动复制工具
#   切换硬盘读写.app  — 调起 Terminal 运行 mount-rw.command，把 NTFS 卷切成读写
#
# 用法：bash app/install-shortcuts.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/硬盘复制助手.app"
MOUNT="$HERE/mount-rw.command"
DESKTOP="$HOME/Desktop"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -d "$APP" ] || { echo "❌ 未找到 $APP，请先运行 bash app/build.sh"; exit 1; }
[ -f "$MOUNT" ] || { echo "❌ 未找到 $MOUNT"; exit 1; }
[ -w "$MOUNT" ] || chmod +x "$MOUNT" 2>/dev/null || true

# ---- 生成图标（青绿=复制，琥珀=挂载）----
cat > "$TMP/icon.swift" <<'SWIFT'
import AppKit
let args = CommandLine.arguments
let out = args[1], mode = args[2]
let size = 512
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect.insetBy(dx: 16, dy: 16), xRadius: 96, yRadius: 96)
let colors = mode == "copy"
    ? [NSColor(srgbRed: 0.11, green: 0.75, blue: 0.65, alpha: 1),
       NSColor(srgbRed: 0.04, green: 0.47, blue: 0.41, alpha: 1)]
    : [NSColor(srgbRed: 0.98, green: 0.72, blue: 0.30, alpha: 1),
       NSColor(srgbRed: 0.85, green: 0.48, blue: 0.09, alpha: 1)]
NSGradient(colors: colors)!.draw(in: path, angle: -90)
let glyph = mode == "copy" ? "⇄" : "⏻"
let str = NSAttributedString(string: glyph, attributes: [
    .font: NSFont.systemFont(ofSize: 260, weight: .bold),
    .foregroundColor: NSColor.white])
let s = str.size()
str.draw(at: NSPoint(x: (CGFloat(size) - s.width) / 2, y: (CGFloat(size) - s.height) / 2))
img.unlockFocus()
if let t = img.tiffRepresentation, let r = NSBitmapImageRep(data: t),
   let p = r.representation(using: .png, properties: [:]) {
    try? p.write(to: URL(fileURLWithPath: out))
}
SWIFT

swift "$TMP/icon.swift" "$TMP/copy.png" copy 2>/dev/null
swift "$TMP/icon.swift" "$TMP/mount.png" mount 2>/dev/null

build_icns() {
    local png="$1" out="$2" name="$3" set="$TMP/${3}.iconset"
    mkdir -p "$set"
    for s in 16 32 128 256 512; do
        sips -z $s $s "$png" --out "$set/icon_${s}x${s}.png" >/dev/null 2>&1
        sips -z $((s*2)) $((s*2)) "$png" --out "$set/icon_${s}x${s}@2x.png" >/dev/null 2>&1
    done
    iconutil -c icns "$set" -o "$out" >/dev/null 2>&1 || true
}
build_icns "$TMP/copy.png" "$TMP/copy.icns" copy
build_icns "$TMP/mount.png" "$TMP/mount.icns" mount

# ---- 构建标准 .app 包（不用 osacompile，避免 Assets.car 覆盖自定义图标）----
build_app() {
    local out="$1" icon="$2" name="$3" bid="$4" cmd="$5"
    rm -rf "$out"
    mkdir -p "$out/Contents/MacOS" "$out/Contents/Resources"
    [ -f "$icon" ] && cp "$icon" "$out/Contents/Resources/icon.icns"
    cat > "$out/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>CFBundleName</key><string>${name}</string>
	<key>CFBundleDisplayName</key><string>${name}</string>
	<key>CFBundleIdentifier</key><string>${bid}</string>
	<key>CFBundleVersion</key><string>1.0</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleExecutable</key><string>launcher</string>
	<key>CFBundleIconFile</key><string>icon.icns</string>
	<key>LSMinimumSystemVersion</key><string>12.0</string>
	<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
    printf '#!/bin/bash\n%s\n' "$cmd" > "$out/Contents/MacOS/launcher"
    chmod +x "$out/Contents/MacOS/launcher"
    codesign --force --sign - "$out" >/dev/null 2>&1 || true
    xattr -dr com.apple.quarantine "$out" 2>/dev/null || true
}

build_app "$DESKTOP/硬盘复制助手.app" "$TMP/copy.icns" "硬盘复制助手" \
    "com.safedrive.launcher.copy" "open -a '$APP'"
build_app "$DESKTOP/切换硬盘读写.app" "$TMP/mount.icns" "切换硬盘读写" \
    "com.safedrive.launcher.mount" "open -a Terminal '$MOUNT'"

echo "✅ 桌面快捷方式已安装："
echo "   ~/Desktop/硬盘复制助手.app   → 启动复制工具"
echo "   ~/Desktop/切换硬盘读写.app   → 切换 NTFS 卷为读写"
