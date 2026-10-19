#!/usr/bin/env bash
# 硬盘复制助手 · 一键编译脚本
# 产出：app/硬盘复制助手.app（swiftc 单可执行 + 手工 .app 包结构 + ad-hoc 签名）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="硬盘复制助手"
BUNDLE="${APP_NAME}.app"
CONTENTS="${BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RES_DIR="${CONTENTS}/Resources"

mkdir -p "${MACOS_DIR}" "${RES_DIR}"

echo "[1/4] swiftc 编译（Swift 5 模式，arm64，min macOS 12）……"
swiftc -swift-version 5 -O -target arm64-apple-macos12.0 \
    -o "${MACOS_DIR}/${APP_NAME}" \
    Sources/main.swift \
    Sources/CopyEngine.swift \
    Sources/ContentView.swift \
    Sources/Logger.swift \
    Sources/VolumeLocator.swift \
    Sources/Diagnostics.swift

echo "[2/4] 组装 .app 包……"
cp Resources/Info.plist "${CONTENTS}/Info.plist"
printf 'APPL????' > "${CONTENTS}/PkgInfo"

echo "[3/4] ad-hoc 签名……"
if codesign --force --sign - "${BUNDLE}" 2>/dev/null; then
    echo "      签名完成"
else
    echo "      跳过签名（本机直接运行不受影响）"
fi

echo "[4/4] 完成：${BUNDLE}"
