#!/bin/bash
# NTFS 移动硬盘 · 读写重挂载助手（FUSE-T + ntfs-3g）
#
# 作用：把 macOS 默认「只读」挂载的 NTFS 卷换成「读写」挂载。
# 前提：已安装 FUSE-T 与 ntfs-3g，且 Terminal 已获「完全磁盘访问权限」。
# 安全：只做卸载/挂载动作，不增删改硬盘上的任何文件。
# 用法：双击运行（会弹出管理员密码授权）。
#       也可在终端指定卷标：./mount-rw.command "My Drive"

HELPER="/usr/local/bin/ntfs-3g"

echo "════════════════════════════════════════"
echo "  NTFS 读写重挂载助手"
echo "════════════════════════════════════════"

# 1. 定位 NTFS 分区（Windows 分区类型为 Microsoft Basic Data）
if [ $# -ge 1 ]; then
    VOLNAME="$1"
    DEV=$(diskutil list | awk -v n="$VOLNAME" '
        /Microsoft Basic Data/ {
            name = $0
            sub(/.*Microsoft Basic Data[[:space:]]+/, "", name)
            sub(/[[:space:]]+[0-9.]+ [KMGT]B.*$/, "", name)
            if (name == n) { print $NF; exit }
        }')
else
    DEV=$(diskutil list | awk '/Microsoft Basic Data/ { print $NF; exit }')
    [ -n "$DEV" ] && VOLNAME=$(diskutil info "$DEV" 2>/dev/null | awk -F': *' '/Volume Name/ {print $2}')
fi

if [ -z "$DEV" ]; then
    echo "❌ 没有找到 NTFS 分区。请确认移动硬盘已插好（且为 NTFS 格式）。"
    echo "按任意键关闭…"; read -n 1 -s; exit 1
fi
[ -z "$VOLNAME" ] && VOLNAME=$(diskutil info "$DEV" 2>/dev/null | awk -F': *' '/Volume Name/ {print $2}')
[ -z "$VOLNAME" ] && VOLNAME="NTFS"

MOUNTPOINT="/Volumes/$VOLNAME"
echo "✔ 找到分区：/dev/$DEV（$VOLNAME）"

if [ ! -x "$HELPER" ]; then
    echo "❌ 未找到 $HELPER"
    echo "   请先安装 FUSE-T 与 ntfs-3g（见项目 README 的「驱动安装」一节）。"
    echo "按任意键关闭…"; read -n 1 -s; exit 2
fi

CONSOLE_UID=$(stat -f %u /dev/console)
CONSOLE_GID=$(stat -f %g /dev/console)
TMPSH="/tmp/ntfs-remount-root.sh"

cat > "$TMPSH" <<EOF
#!/bin/bash
if mount | grep -q " on $MOUNTPOINT "; then
    umount "$MOUNTPOINT" 2>/dev/null || diskutil unmount "$DEV" >/dev/null 2>&1 || { echo UNMOUNT_FAIL; exit 21; }
fi
mkdir -p "$MOUNTPOINT"
"$HELPER" -o local,allow_other,auto_xattr,auto_cache,noatime,windows_names,big_writes,uid=$CONSOLE_UID,gid=$CONSOLE_GID "/dev/$DEV" "$MOUNTPOINT" 2>&1
RC=\$?
sleep 2
if mount | grep -q " on $MOUNTPOINT " && touch "$MOUNTPOINT/.rw-test" 2>/dev/null; then
    rm -f "$MOUNTPOINT/.rw-test"
    echo MOUNT_OK
else
    echo MOUNT_FAIL_RC_\$RC
    diskutil mount "$DEV" >/dev/null 2>&1
    exit 23
fi
EOF
chmod 700 "$TMPSH"

echo "请在下面输入你的开机密码（输入时屏幕不显示字符，输完按回车）："
sudo bash "$TMPSH"
RC=$?
rm -f "$TMPSH"

echo "──────────────────────────────────────"
if mount | grep " on $MOUNTPOINT " | grep -qv read-only; then
    echo "✅ $VOLNAME 已可读写！可以关闭本窗口。"
else
    echo "⚠️ 读写挂载未成功，硬盘保持原挂载状态（你的文件无任何变化）。"
    echo "   常见原因："
    echo "   ① 终端没有「完全磁盘访问权限」——系统设置 › 隐私与安全性 › 完全磁盘访问权限 › 添加『终端』"
    echo "   ② 硬盘上次在 Windows 未正常弹出——插回 Windows 完整关机（不要快速启动/休眠）后再试"
fi
echo "按任意键关闭…"; read -n 1 -s
exit $RC
