APP_NAME := LikeWindows
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := $(HOME)/Applications

.PHONY: all build run start restart install login-item uninstall clean config regrant identity status \
        icon release release-dry notary-setup notary-log help

all: build

build:
	./build.sh

run: build
	open $(APP)

# 前台运行（方便在终端看日志）
start:
	$(APP)/Contents/MacOS/$(APP_NAME)

install: build
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(APP) $(INSTALL_DIR)/$(APP_NAME).app
	@echo "已安装到 $(INSTALL_DIR)/$(APP_NAME).app"

# 开机自启（登录项）
login-item:
	osascript -e 'tell application "System Events" to delete login item "$(APP_NAME)"' >/dev/null 2>&1 || true
	osascript -e 'tell application "System Events" to make login item at end with properties {path:"$(INSTALL_DIR)/$(APP_NAME).app", hidden:false}' >/dev/null
	@echo "已添加登录项：$(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	osascript -e 'tell application "System Events" to delete login item "$(APP_NAME)"' >/dev/null 2>&1 || true
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@echo "已卸载"

config:
	@cat $(HOME)/.config/likewindows/config.json 2>/dev/null || echo "还没有配置文件，启动一次 App 后会自动生成"

# 诊断：签名、是否有旧进程在跑、最近日志
status:
	./scripts/status.sh

# 杀掉旧进程重新启动（重新编译后务必用它，否则跑的还是旧二进制）
restart:
	-pkill -f "LikeWindows.app/Contents/MacOS/[L]ikeWindows"
	@sleep 0.6
	open "$(APP)"

# 清掉旧的辅助功能授权记录，下次启动重新弹窗（换签名后必须做一次）
regrant:
	-tccutil reset Accessibility com.harryliang.likewindows
	@echo "已清除旧授权记录。接着执行："
	@echo "  make build && make run   # 然后点系统弹窗里的「打开系统设置」并勾选 LikeWindows"

identity:
	@security find-identity -v -p codesigning

# ---------------- 图标 ----------------

# 重新生成 App 图标（Resources/AppIcon.icns + build/icon-1024.png 预览）
icon:
	swift scripts/make-icon.swift

# ---------------- 发布 ----------------

# 正式发布：Developer ID 签名(Hardened Runtime) → 公证 → 装订 → DMG → 校验
#   make release                 版本号取自 Resources/Info.plist
#   make release VERSION=1.1.0
release:
	VERSION="$(VERSION)" NOTARY_PROFILE="$(PROFILE)" ./scripts/release.sh

# 本地演练：ad-hoc 签名，跳过公证，验证打包和 DMG 流程是否正常
release-dry:
	DRY_RUN=1 ./scripts/release.sh

# 一次性保存公证凭证到钥匙串（profile 名默认 likewindows-notary）
# 需要：Apple ID、Team ID、App 专用密码 https://appleid.apple.com/account/manage
PROFILE ?= likewindows-notary
notary-setup:
	xcrun notarytool store-credentials "$(PROFILE)" --team-id PZ2MRMSK6A

# 查看某次公证的失败原因：make notary-log ID=xxxx
notary-log:
	@test -n "$(ID)" || (echo "用法：make notary-log ID=<submission-id>"; exit 1)
	xcrun notarytool log "$(ID)" --keychain-profile "$(PROFILE)"

help:
	@grep -E '^# ' Makefile | sed 's/^# //'
	@echo ""
	@echo "常用：make build / make run / make restart / make status / make release-dry"

clean:
	rm -rf .build $(BUILD_DIR) dist
