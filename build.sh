#!/usr/bin/env bash
# 编译并打包成 LikeWindows.app
set -euo pipefail
cd "$(dirname "$0")"

echo "==> swift build -c release"
swift build -c release

APP_DIR="build/LikeWindows.app"
BIN="$(swift build -c release --show-bin-path)/LikeWindows"

echo "==> 打包 $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN" "$APP_DIR/Contents/MacOS/LikeWindows"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

# App 图标：缺失时自动用脚本生成（图标是代码画的，不存进仓库）
if [ ! -f Resources/AppIcon.icns ]; then
  echo "==> 生成图标"
  swift scripts/make-icon.swift >/dev/null
fi
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_DIR/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_DIR/Contents/Info.plist"
  echo "    图标：Resources/AppIcon.icns"
fi

# 签名：优先用本机已有的 Apple 开发证书。
# ad-hoc 签名的 designated requirement 是 cdhash，每次编译都变 → 辅助功能授权失效；
# 用固定证书签名后 requirement 稳定，授权一次长期有效。
IDENTITY="${LIKE_WINDOWS_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development: [^"]*\)"/\1/p' | head -1)"
fi
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)"/\1/p' | head -1)"
fi
SIGNED=0
if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "-" ]; then
  if codesign --force --sign "$IDENTITY" --identifier com.harryliang.likewindows "$APP_DIR" 2>/tmp/likewindows-codesign.log; then
    SIGNED=1
    echo "    签名身份：$IDENTITY"
    echo "    辅助功能授权一次后长期有效（证书不变，requirement 稳定）"
  else
    echo "    用开发证书签名失败（钥匙串里的私钥没被放行）："
    sed 's/^/      /' /tmp/likewindows-codesign.log
    echo "    → 在你自己的「终端」里跑一次 make build，钥匙串弹窗点「始终允许」"
    echo "      之后签名就稳定了，辅助功能授权不会再丢"
  fi
fi

if [ "$SIGNED" = "0" ]; then
  codesign --force --sign - --identifier com.harryliang.likewindows "$APP_DIR" >/dev/null
  echo "    签名身份：ad-hoc"
  echo "    注意：ad-hoc 签名每次重新编译都会变，辅助功能授权会失效"
  echo "          重新编译后用 make regrant 清掉旧授权，再启动重新授权一次"
fi

# 让 Launch Services 认识这个 bundle
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" 2>/dev/null || true

echo "==> 完成：$APP_DIR"
echo "    运行：open $APP_DIR"
