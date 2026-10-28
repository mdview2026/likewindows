#!/usr/bin/env bash
# 诊断：签名 / 运行中的进程 / 授权日志
set -uo pipefail
cd "$(dirname "$0")/.."

APP="build/LikeWindows.app"
BIN="$APP/Contents/MacOS/LikeWindows"
LOG="$HOME/Library/Logs/LikeWindows.log"

echo "== 1. 磁盘上的 App =="
if [ ! -d "$APP" ]; then
  echo "  还没编译过：make build"
  exit 1
fi
if codesign -dv --verbose=2 "$APP" 2>&1 | grep -q '^Signature=adhoc'; then
  echo "  签名: ad-hoc  ⚠️ 每次重新编译辅助功能授权都会失效"
else
  codesign -dv --verbose=2 "$APP" 2>&1 | grep -E '^(Signature|Authority=Apple Development|Authority=Developer ID)' | sed 's/^/  /'
  echo "  ✅ 证书签名：授权一次长期有效"
fi
echo "  bundle: $(cd "$APP/.." && pwd)/$(basename "$APP")"
APP_MTIME=$(stat -f %m "$BIN" 2>/dev/null || echo 0)

echo
echo "== 2. 运行中的实例 =="
PIDS=$(pgrep -f "LikeWindows.app/Contents/MacOS/[L]ikeWindows" || true)
if [ -z "$PIDS" ]; then
  echo "  没有在运行：make run"
else
  for pid in $PIDS; do
    start=$(ps -o lstart= -p "$pid" 2>/dev/null | sed 's/^ *//')
    start_epoch=$(date -j -f "%a %b %d %T %Y" "$start" "+%s" 2>/dev/null || echo 0)
    echo "  pid $pid  启动于 $start"
    if [ "$start_epoch" -gt 0 ] && [ "$APP_MTIME" -gt "$start_epoch" ]; then
      echo "  ⚠️  这个进程比磁盘上的 App 旧（跑的是编译前的旧二进制）"
      echo "      → make restart"
    else
      echo "  ✅ 跑的是最新编译的二进制"
    fi
  done
fi

echo
echo "== 3. 最近日志 =="
if [ -f "$LOG" ]; then
  tail -6 "$LOG" | sed 's/^/  /'
  if tail -50 "$LOG" | grep -q "没有辅助功能权限"; then
    echo
    echo "  ⚠️  仍在报「没有辅助功能权限」："
    echo "     1) 系统设置 → 隐私与安全性 → 辅助功能，勾选 LikeWindows"
    echo "     2) 列表里没有它 → make regrant && make run，然后在系统弹窗里点「打开系统设置」"
  fi
else
  echo "  还没有日志（App 没启动过）"
fi
