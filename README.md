# 硬盘复制助手 · SafeDrive Copy

一个 macOS 原生、**绝不删除、绝不覆盖**的图形化文件复制工具，专为「Mac 与 NTFS 移动硬盘互拷」设计。拖拽即用，复制后自动校验。

> 起因：macOS 原生只能**只读**挂载 NTFS，且 Finder 复制大文件时经常出现「同名覆盖无提示」「复制中断留下半截文件」等问题。这个工具用**临时文件 + 校验 + 原子改名**的协议消除这些风险。

## 功能

- **拖拽复制**：文件/文件夹拖进窗口即可，文件夹自动递归展开并保留子目录结构
- **双向**：Mac → 硬盘、硬盘 → Mac，按目标位置自动判断
- **绝不覆盖**：默认同名跳过，可选自动改名（`名字 (1).ext`）
- **绝不删除**：主程序不链接任何删除 API（源码级审计零命中）
- **先校验后转正**：先写 `.<文件名>.xfertmp` → 校验字节数（可选 SHA-256 逐字节）→ 原子 rename
- **可取消**：中途取消立即停止，只清理本次运行自己创建的临时文件
- **保留修改时间**
- **先拷后开**：一键把硬盘文件复制到本机临时目录并打开（绕过 FUSE-T 不支持 `F_RDADVISE` 导致的媒体文件卡死）
- **环境自检**：一键导出目标卷可写性、文件夹权限、挂载信息，便于排障
- **全流程日志**：`~/Library/Logs/硬盘复制助手.log`

## 截图

![主界面](docs/images/main.png)

> 若图片缺失，运行 App 后按 `Cmd+Shift+4` 截图放到 `docs/images/main.png`。

## 系统要求

- macOS 12 或更新（在 macOS 26.5 Apple Silicon 上开发与测试）
- 写入 NTFS 需要额外驱动（见下）

## 快速开始

```bash
git clone <this-repo>
cd <repo>
bash app/build.sh            # 产出 app/硬盘复制助手.app
open app/硬盘复制助手.app
```

### 桌面快捷方式

```bash
bash app/install-shortcuts.sh
```

会在桌面生成两个带图标的启动器：

- **硬盘复制助手** — 直接启动复制工具
- **切换硬盘读写** — 调起终端运行 `mount-rw.command`，把 NTFS 卷切换为读写

首次运行需要在 **系统设置 → 隐私与安全性 → 完全磁盘访问权限** 中给「硬盘复制助手」打开开关，否则读不到「桌面 / 下载 / 文稿」里的文件。授权后需退出 App 重新打开。

## 让 NTFS 可写（macOS 只读限制）

macOS 原生只能读 NTFS。以下任一方案可让本工具写入硬盘：

### 方案 A：FUSE-T + ntfs-3g（免费）

```bash
brew install --cask fuse-t
# 启动一次 FUSE-T 以注册 FSKit 模块
open /Applications/fuse-t.app
```

再编译安装 ntfs-3g（Homebrew 的 `ntfs-3g` formula 仅支持 Linux，需从源码编译）：

```bash
curl -L -O https://github.com/tuxera/ntfs-3g/archive/refs/tags/2026.9.28.tar.gz
tar xzf 2026.9.28.tar.gz && cd ntfs-3g-2026.9.28
brew install autoconf automake libtool pkgconf libgcrypt
export ACLOCAL_PATH=/opt/homebrew/share/aclocal
autoreconf --install --force

# FUSE-T 的 pkg-config 模块名是 fuse-t，ntfs-3g 找的是 fuse，需要垫片
mkdir -p /tmp/pc && sed 's/^Name:.*/Name: fuse/; s/^Version:.*/Version: 2.6.2/' \
  "/Library/Application Support/fuse-t/pkgconfig/fuse-t.pc" > /tmp/pc/fuse.pc
PKG_CONFIG_PATH=/tmp/pc ./configure --with-fuse=external --prefix=/usr/local --disable-ldconfig
make -j8 CFLAGS="-g -O2 -D_FILE_OFFSET_BITS=64"
sudo install -m 0755 src/.libs/ntfs-3g /usr/local/bin/
```

插盘后双击 `app/mount-rw.command` 把卷切换为读写挂载（脚本自动识别 NTFS 分区，也可传卷标参数）。

> **已知限制**：FUSE-T 的 NFS 后端不实现 `F_RDADVISE`，导致 QuickTime 等播放器直接打开硬盘上的视频会卡死。请用 App 里的「拷到本机并打开」。详见 [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md)。

### 方案 B：商业驱动

Paragon NTFS for Mac / Tuxera NTFS 安装后即可原生读写，无需 `mount-rw.command`。注意 Apple Silicon 在「完全安全性」模式下**禁止第三方内核扩展**，需在恢复模式降低安全级别才能加载（会削弱整机安全，请自行权衡）。

## 安全设计

| 铁律 | 实现 |
|---|---|
| 不删除 | 主程序不链接 `removeItem` / `moveItem` / `trashItem` / `unlink`；源码审计零命中 |
| 不覆盖 | 复制前与 rename 前各检查一次目标是否存在；默认跳过，可选改名 |
| 不产生半截文件 | 先写 `.<名字>.xfertmp`，校验通过后才 `rename()` 转正 |
| 校验 | 字节数必做；可选 CryptoKit SHA-256 逐字节比对 |
| 取消安全 | 只清理「本次运行登记 + 命名模式匹配」的自有临时文件；任何用户文件都无法命中该条件 |

## 项目结构

```
app/
  Sources/
    main.swift          # 入口、窗口、菜单
    ContentView.swift   # 全部 UI（AppKit 手写布局）
    CopyEngine.swift    # 安全复制引擎 + 拖入递归展开
    VolumeLocator.swift # 外接卷识别（NTFS / 读写状态）
    Diagnostics.swift   # 环境自检
    Logger.swift        # 文件日志
  Resources/Info.plist
  build.sh              # swiftc 编译 + .app 组装 + ad-hoc 签名
  mount-rw.command      # NTFS 读写重挂载助手
qa/
  engine-regression/    # 复制引擎回归测试（12 项）
  run-engine-test.sh
docs/
  SPEC.md               # 功能与安全规格
  KNOWN-ISSUES.md       # 已知限制与原因
check.sh                # 一键验收
```

## 验收

```bash
bash check.sh
```

包含：编译、S1 删除 API 审计、启动冒烟、引擎回归 12 项。

## 许可

MIT License，见 [LICENSE](LICENSE)。

## 致谢

- [ntfs-3g](https://github.com/tuxera/ntfs-3g) — 开源 NTFS 读写驱动
- [FUSE-T](https://github.com/macos-fuse-t/fuse-t) — 无内核扩展的 FUSE 实现
