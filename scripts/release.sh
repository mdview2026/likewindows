#!/usr/bin/env bash
#
# 发布流水线：编译 → Developer ID 签名（Hardened Runtime）→ 公证 → stapler 装订 → 打 DMG → 校验
#
#   make release              正式发布（需要 Developer ID 证书 + 公证凭证）
#   make release-dry          本地演练：ad-hoc 签名，跳过公证，只验证打包与 DMG 流程
#   make notary-setup         一次性保存公证凭证到钥匙串
#
# 可用环境变量：
#   LIKE_WINDOWS_SIGN_IDENTITY   指定签名身份（默认自动找 Developer ID Application）
#   NOTARY_PROFILE               公证凭证的钥匙串 profile 名（默认 likewindows-notary）
#   VERSION / BUILD              覆盖版本号 / 构建号
#   DRY_RUN=1                    跳过签名与公证
#
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="LikeWindows"
BUNDLE_ID="com.harryliang.likewindows"
DIST="dist"
STAGE="$DIST/stage"
APP="$STAGE/$APP_NAME.app"
PROFILE="${NOTARY_PROFILE:-likewindows-notary}"
DRY_RUN="${DRY_RUN:-0}"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)}"
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"

step()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note()  { printf '    %s\n' "$*"; }
fail()  { printf '\n\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# 公证失败时把 submission id 打出来，方便查 Apple 的日志
notarize() {
  local target="$1" out id
  if ! out="$(xcrun notarytool submit "$target" --keychain-profile "$PROFILE" --wait 2>&1)"; then
    echo "$out"
    id="$(printf '%s\n' "$out" | awk '/^ *id: /{print $2; exit}')"
    printf '\n\033[31m✗ 公证失败\033[0m\n' >&2
    [ -n "${id:-}" ] && note "查看原因：make notary-log ID=$id"
    note "凭证没配好？先跑一次：make notary-setup（profile: ${PROFILE}）"
    exit 1
  fi
  printf '%s\n' "$out" | grep -E '^ *(id|status): ' | sed 's/^ */    /'
}

# ---------------------------------------------------------------- 0. 前置检查
step "环境检查"
[ "$(uname -s)" = "Darwin" ] || fail "只能在 macOS 上发布"

if [ "$DRY_RUN" = "1" ]; then
  SIGN_ID="-"
  note "演练模式（DRY_RUN=1）：ad-hoc 签名，跳过公证"
else
  SIGN_ID="${LIKE_WINDOWS_SIGN_IDENTITY:-}"
  if [ -z "$SIGN_ID" ]; then
    SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application: [^"]*\)"/\1/p' | head -1)"
  fi
  [ -n "$SIGN_ID" ] || fail "找不到 Developer ID Application 证书。
    在 Xcode → Settings → Accounts → Manage Certificates 里创建一个，
    或 https://developer.apple.com/account/resources/certificates 申请后导入钥匙串。"
  case "$SIGN_ID" in
    *"Developer ID Application"*) : ;;
    *) fail "发布必须用 Developer ID Application 签名，当前是：$SIGN_ID
    （Apple Development 只适合本机调试，别人下载后无法通过 Gatekeeper）" ;;
  esac
  xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
    || fail "公证凭证「${PROFILE}」不可用。先跑：make notary-setup"
  note "签名身份：$SIGN_ID"
  note "公证凭证：$PROFILE"
fi
note "版本：${VERSION}（build ${BUILD}）"

# ---------------------------------------------------------------- 1. 编译
step "编译"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
[ -f "$BIN" ] || fail "编译产物不存在：$BIN"

# ---------------------------------------------------------------- 2. 组装 Bundle
step "组装 App Bundle"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
if [ ! -f Resources/AppIcon.icns ]; then
  note "图标不存在，先生成"
  swift scripts/make-icon.swift >/dev/null || fail "图标生成失败"
fi
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"
  note "图标：Resources/AppIcon.icns"
else
  note "图标：未提供（放一个 Resources/AppIcon.icns 就会自动带上）"
fi
note "$APP"

# ---------------------------------------------------------------- 3. 签名
step "签名（Hardened Runtime）"
if [ "$DRY_RUN" = "1" ]; then
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
else
  if ! out="$(codesign --force --options runtime --timestamp \
              --sign "$SIGN_ID" --identifier "$BUNDLE_ID" "$APP" 2>&1)"; then
    printf '%s\n' "$out" | sed 's/^/    /'
    case "$out" in
      *errSecInternalComponent*)
        fail "钥匙串没有放行这把私钥。
    请在图形界面的「终端」里重跑 make release，弹窗点「始终允许」。"
        ;;
      *) fail "签名失败" ;;
    esac
  fi
fi
codesign --verify --strict --verbose=2 "$APP" 2>&1 | sed 's/^/    /'

# ---------------------------------------------------------------- 4. 公证 App
if [ "$DRY_RUN" = "1" ]; then
  step "公证 App（演练模式跳过）"
else
  step "公证 App"
  ditto -c -k --keepParent "$APP" "$DIST/app-notarize.zip"
  notarize "$DIST/app-notarize.zip"
  xcrun stapler staple "$APP" | sed 's/^/    /'
  rm -f "$DIST/app-notarize.zip"
fi

# ---------------------------------------------------------------- 5. DMG
step "制作 DMG"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
ln -sfn /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
if [ "$DRY_RUN" != "1" ]; then
  codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
fi
note "${DMG}（$(du -h "$DMG" | cut -f1)）"

# ---------------------------------------------------------------- 6. 公证 DMG
if [ "$DRY_RUN" = "1" ]; then
  step "公证 DMG（演练模式跳过）"
else
  step "公证 DMG"
  notarize "$DMG"
  xcrun stapler staple "$DMG" | sed 's/^/    /'
fi

# ---------------------------------------------------------------- 7. 校验
step "Gatekeeper 校验"
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E '^(Identifier|TeamIdentifier|Authority|Signature|Timestamp)' | sed 's/^/    /'
codesign -d --verbose=2 "$APP" 2>&1 | grep -q 'flags=.*runtime' \
  && note "Hardened Runtime：已开启" || note "Hardened Runtime：未开启（仅演练模式会出现）"

if spctl -a -t exec -vv "$APP" 2>&1 | sed 's/^/    /'; then
  note "App：Gatekeeper 通过"
else
  note "App：Gatekeeper 未通过（演练模式下属正常）"
fi

if [ "$DRY_RUN" != "1" ]; then
  if spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 | sed 's/^/    /'; then
    note "DMG：Gatekeeper 通过"
  else
    fail "DMG 未通过 Gatekeeper，检查公证是否真的成功"
  fi
fi

# ---------------------------------------------------------------- 完成
step "完成"
note "分发文件：${DMG}"
note "本地试跑：open \"${APP}\""
note "提醒：App 换了签名/路径后需要重新授权辅助功能。"
