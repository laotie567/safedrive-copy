#!/bin/bash
# 复制引擎回归测试（真实读写外接卷，测试后自清理）
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
swiftc -swift-version 5 -O -o "$OUT/engine-test" \
    "$ROOT/qa/engine-regression/main.swift" \
    "$ROOT/qa/engine-regression/helpers.swift" \
    "$ROOT/app/Sources/CopyEngine.swift" \
    "$ROOT/app/Sources/Logger.swift" \
    "$ROOT/app/Sources/VolumeLocator.swift" 2>&1 | grep -E "error" && exit 2
"$OUT/engine-test" 2>&1 | grep -vE "^\[|启动 session"
