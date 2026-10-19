# 已知限制

## 1. FUSE-T 下硬盘里的视频/文档双击打不开

**现象**：在 Finder 或 QuickTime 里直接双击 NTFS 卷上的视频、文档，播放器无反应（时长显示 `0.0`、`NaN`）。

**原因**（实测定位）：

FUSE-T 1.2.9 的 NFS 后端没有实现 `F_RDADVISE` 这个 macOS 媒体框架（AVFoundation / CoreMedia）依赖的预读系统调用：

```
F_RDADVISE  → Inappropriate ioctl for device
pread / mmap / flock / F_NOCACHE → 正常
```

播放器调用后进入**不可中断睡眠（进程状态 U）**，永久等待；且该阻塞会连带堵死同一挂载的写入路径，表现为「复制突然卡住不结束」。

**证据**：同一文件在卷上的 MD5 与复制到本机后完全一致；QuickLook 可在 0.16 秒内生成缩略图；复制到本机后播放器立即正常（`duration` 正确）。

**绕过方式**：使用 App 的 **「拷到本机并打开」** —— 复制到 `$TMPDIR/硬盘复制助手-先拷后开/` 后自动打开。

**已排查失败的替代方案**：

| 方案 | 结果 |
|---|---|
| FUSE-T `backend=fskit` | 挂载反复失败（`mount -t fuset` exit 72），1.2.9 在 macOS 26.5 上的实现问题 |
| Paragon NTFS 18 | 驱动被系统拒绝：`3rd Party Kexts Status: Disabled`（Apple Silicon「完全安全性」模式限制） |

## 2. 大文件长时间写入可能让挂载僵死

FUSE-T NFS 后端在持续大流量写入后偶发挂死。建议：

- 单次复制控制在数 GB 以内，或分批复制
- 写完后在 Finder 里确认目标文件存在
- 若挂载卡住：`diskutil unmount force "/Volumes/<卷名>"`，重新插拔后再次运行 `mount-rw.command`

## 3. 需要「完全磁盘访问权限」

未授权时，读取「桌面 / 下载 / 文稿」会静默失败。App 会在启动时自检并提示；授权后必须**退出并重新打开** App 才生效。重新编译后 ad-hoc 签名变化，系统可能再次要求授权。

## 4. 不支持的场景

- APFS / HFS+ 卷（不需要本工具处理读写，原生可用）
- 加密 NTFS（BitLocker）
- Windows 快速启动 / 休眠未清理的卷（ntfs-3g 会拒绝读写挂载，需回 Windows 完整关机）
