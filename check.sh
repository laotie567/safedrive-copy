#!/usr/bin/env bash
# check.sh —— 移动硬盘读写助手 验证入口（执行者只跑不写）
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PASS=0; FAIL=0
ok(){ echo "✅ $1"; PASS=$((PASS+1)); }
bad(){ echo "❌ $1"; FAIL=$((FAIL+1)); }

# 1. 交付物存在
for f in app/build.sh app/mount-rw.command app/Sources/main.swift app/Sources/CopyEngine.swift app/Sources/ContentView.swift; do
  [ -s "$ROOT/$f" ] && ok "存在 $f" || bad "缺失 $f"
done

# 2. 编译（产物 app/硬盘复制助手.app）
( cd "$ROOT" && bash app/build.sh ) >/tmp/chk-build.log 2>&1 \
  && [ -d "$ROOT/app/硬盘复制助手.app" ] && ok "编译产出 .app" || { bad "编译失败"; tail -5 /tmp/chk-build.log; }

# 3. S1 安全审计：源码零删除API
if ! grep -rnE "removeItem|moveItem|\.Trash|unlink|removeItemAtPath" "$ROOT/app/Sources/" >/dev/null 2>&1; then
  ok "S1 审计：源码零删除API"
else
  bad "S1 审计发现删除API调用:"; grep -rnE "removeItem|moveItem|\.Trash|unlink|removeItemAtPath" "$ROOT/app/Sources/"
fi

# 4. 冒烟：启动存活5秒
if [ -d "$ROOT/app/硬盘复制助手.app" ]; then
  open "$ROOT/app/硬盘复制助手.app" && sleep 5
  pgrep -f "硬盘复制助手" >/dev/null && ok "冒烟：进程存活" || bad "冒烟：进程未存活"
  pkill -f "硬盘复制助手" 2>/dev/null || true
fi

# 5. 引擎回归（真实读写外接卷；需要至少一个可写外接卷）
VOL=$(ls /Volumes 2>/dev/null | grep -v "Macintosh HD" | head -1)
if [ -n "$VOL" ] && ! mount | grep " on /Volumes/$VOL " | grep -q read-only; then
  if bash "$ROOT/qa/run-engine-test.sh" >/tmp/chk-engine.log 2>&1; then
    ok "引擎回归 12/12"
  else
    bad "引擎回归失败"; grep -E "^❌|结果：" /tmp/chk-engine.log | head -5
  fi
else
  echo "⏭  跳过引擎回归（没有可写的外接卷）"
fi

echo "————"; echo "结果: $PASS 绿 / $FAIL 红"; [ $FAIL -eq 0 ]
