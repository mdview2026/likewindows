import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let keyTap = KeyTap()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var configDate: Date?
    private var watchdog: Timer?

    private var config: Config { ConfigStore.shared.value }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("启动 LikeWindows，辅助功能权限=\(Permissions.isTrusted)")
        ConfigStore.shared.load()
        // 首次启动写一份默认配置，方便用户直接改
        if !FileManager.default.fileExists(atPath: ConfigStore.shared.fileURL.path) {
            ConfigStore.shared.save()
        }
        setupStatusItem()
        setupTap()
        syncClipboardStore()
        setupConfigWatch()
        showOnboardingIfNeeded()
        debugShowPanelIfRequested()
    }

    /// 调试用：--panel 直接打开剪贴板面板（不用授予键盘监听权限）
    private func debugShowPanelIfRequested() {
        guard CommandLine.arguments.contains("--panel") else { return }
        let samples = [
            "https://github.com/harryliang/like_windows",
            "git commit -m \"fix: 贴边分屏在跨屏时坐标错位\"",
            "SELECT id, title FROM notes WHERE updated_at > now() - interval '7 days';",
            "今天下午 3 点跟产品对一下 Win+D 的交互细节",
            "ssh harryliang@192.168.1.20 -p 2222",
        ]
        samples.forEach { ClipboardStore.shared.record($0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ClipboardPanelController.shared.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyTap.stop()
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let symbol = ["rectangle.split.2x1", "square.split.2x1", "rectangle.split.3x1"]
                .compactMap { NSImage(systemSymbolName: $0, accessibilityDescription: "LikeWindows") }
                .first
            if let symbol {
                symbol.isTemplate = true
                button.image = symbol
            } else {
                button.title = "W"
            }
        }
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon()
    }

    private func setupTap() {
        keyTap.onAvailabilityChange = { [weak self] in
            DispatchQueue.main.async { self?.refreshIcon(); self?.rebuildMenu() }
        }
        keyTap.start()

        // 权限是后来才授予的：一直等，直到监听成功
        guard !keyTap.isRunning else { return }
        let retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.keyTap.start() { timer.invalidate() }
        }
        RunLoop.main.add(retry, forMode: .common)
    }

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        if !config.enabled {
            button.appearsDisabled = true
            button.toolTip = "LikeWindows 已暂停"
        } else if !Permissions.isTrusted {
            button.appearsDisabled = true
            button.toolTip = "LikeWindows 需要「辅助功能」权限"
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                   accessibilityDescription: "需要权限")
        } else {
            button.appearsDisabled = false
            button.image = NSImage(systemSymbolName: "rectangle.split.2x1",
                                   accessibilityDescription: "LikeWindows")
            button.image?.isTemplate = true
            button.toolTip = "LikeWindows — Win 键：\(config.winKey.displayName)"
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let trusted = Permissions.isTrusted
        let header = NSMenuItem(title: trusted ? "LikeWindows 运行中" : "⚠️ 缺少辅助功能权限",
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if !trusted {
            let grant = NSMenuItem(title: "① 授权辅助功能…", action: #selector(requestAccessibility), keyEquivalent: "")
            menu.addItem(grant)
            menu.addItem(NSMenuItem(title: "② 重新注册授权（列表里看不到本 App 时用）",
                                    action: #selector(reregister), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "③ 在访达中显示（手动拖进授权列表）",
                                    action: #selector(openAppFolder), keyEquivalent: ""))
            menu.addItem(.separator())
        }

        let enabledItem = NSMenuItem(title: "启用", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.state = config.enabled ? .on : .off
        menu.addItem(enabledItem)

        // Windows 键盘：Win 键就是 ⌘，一键切换
        let keyboardItem = NSMenuItem(title: config.winKey.consumesCommandKey
                                        ? "键盘：Windows 键盘（Win 键 = ⌘）"
                                        : "键盘：Mac 键盘（右侧 ⌘ 当 Win 键）",
                                      action: #selector(toggleWindowsKeyboardMode), keyEquivalent: "")
        keyboardItem.state = config.winKey.consumesCommandKey ? .on : .off
        keyboardItem.toolTip = "PC 键盘上按住 Win 键会被 macOS 识别为 ⌘，需要切成这个模式"
        menu.addItem(keyboardItem)

        // Win 键选择
        let winItem = NSMenuItem(title: "Win 键", action: nil, keyEquivalent: "")
        let winMenu = NSMenu()
        for candidate in WinKey.allCases {
            let item = NSMenuItem(title: candidate.displayName, action: #selector(selectWinKey(_:)), keyEquivalent: "")
            item.representedObject = candidate.rawValue
            item.state = candidate == config.winKey ? .on : .off
            winMenu.addItem(item)
        }
        winItem.submenu = winMenu
        menu.addItem(winItem)

        let altItem = NSMenuItem(title: "Alt+Tab / Alt+F4", action: #selector(toggleAltTab), keyEquivalent: "")
        altItem.state = config.altTab ? .on : .off
        altItem.isEnabled = !config.winKey.isOption
        menu.addItem(altItem)

        let tapItem = NSMenuItem(title: "轻按 Win 打开启动台", action: #selector(toggleTapStartMenu), keyEquivalent: "")
        tapItem.state = config.tapForStartMenu ? .on : .off
        menu.addItem(tapItem)

        let snapItem = NSMenuItem(title: "方向键贴边 / 最大化", action: #selector(toggleSnap), keyEquivalent: "")
        snapItem.state = config.snap ? .on : .off
        menu.addItem(snapItem)

        let dockItem = NSMenuItem(title: "Win+1…9 切换 Dock 应用", action: #selector(toggleDockShortcuts), keyEquivalent: "")
        dockItem.state = config.dockShortcuts ? .on : .off
        menu.addItem(dockItem)

        let clipItem = NSMenuItem(title: "Win+V 剪贴板历史", action: #selector(toggleClipboardHistory), keyEquivalent: "")
        clipItem.state = config.clipboardHistory ? .on : .off
        menu.addItem(clipItem)

        menu.addItem(.separator())

        // 手动触发（顺便验证权限是否正常）
        let actions = NSMenuItem(title: "立即执行", action: nil, keyEquivalent: "")
        let actionMenu = NSMenu()
        for binding in KeyTable.activeWinBindings(for: config)
            where binding.modifiers.isEmpty && binding.category != .dock {
            let item = NSMenuItem(title: binding.title, action: #selector(runBinding(_:)), keyEquivalent: "")
            item.representedObject = binding.title
            actionMenu.addItem(item)
        }
        actions.submenu = actionMenu
        menu.addItem(actions)

        let cheatsheet = NSMenuItem(title: "快捷键一览", action: nil, keyEquivalent: "")
        let sheetMenu = NSMenu()
        for binding in KeyTable.activeWinBindings(for: config) + KeyTable.altBindings {
            let item = NSMenuItem(title: binding.title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            sheetMenu.addItem(item)
        }
        let dockHint = NSMenuItem(title: "Win+1…9 切换 Dock 第 n 个应用", action: nil, keyEquivalent: "")
        dockHint.isEnabled = false
        sheetMenu.addItem(dockHint)
        cheatsheet.submenu = sheetMenu
        menu.addItem(cheatsheet)

        menu.addItem(.separator())

        if config.clipboardHistory {
            menu.addItem(NSMenuItem(title: "清空剪贴板历史（\(ClipboardStore.shared.items.count) 条）",
                                    action: #selector(clearClipboardHistory), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: "新手引导…", action: #selector(showOnboarding), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开配置文件", action: #selector(openConfig), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重新加载配置", action: #selector(reloadConfig), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重新开始监听", action: #selector(restartTap), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "记录按键 12 秒（排查键位）", action: #selector(startKeyDiagnostics), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "查看日志", action: #selector(openLog), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "辅助功能设置…", action: #selector(requestAccessibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "清空并重新注册授权", action: #selector(reregister), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 LikeWindows", action: #selector(quit), keyEquivalent: "q"))
    }

    // MARK: - 菜单动作

    @objc private func toggleWindowsKeyboardMode() {
        ConfigStore.shared.update { config in
            if config.winKey.consumesCommandKey {
                config.winKey = .rightCommand
            } else {
                config.winKey = .anyCommand
            }
        }
        Log.write("切换键盘模式：Win 键 = \(config.winKey.displayName)，生效组合 \(KeyTable.activeWinBindings(for: config).count) 个")
        refreshIcon()
    }

    @objc private func startKeyDiagnostics() {
        keyTap.debugLogUntil = Date().addingTimeInterval(12)
        Log.write("按键诊断开始：12 秒内记录所有按键（现在请按一遍 Win+R）")
        DispatchQueue.main.asyncAfter(deadline: .now() + 13) {
            Log.write("按键诊断结束")
        }
    }

    @objc private func toggleEnabled() {
        ConfigStore.shared.update { $0.enabled.toggle() }
        refreshIcon()
    }

    @objc private func selectWinKey(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let candidate = WinKey(rawValue: raw) else { return }
        ConfigStore.shared.update { $0.winKey = candidate }
        refreshIcon()
    }

    @objc private func toggleAltTab() {
        ConfigStore.shared.update { $0.altTab.toggle() }
    }

    @objc private func toggleTapStartMenu() {
        ConfigStore.shared.update { $0.tapForStartMenu.toggle() }
    }

    @objc private func toggleSnap() {
        ConfigStore.shared.update { $0.snap.toggle() }
    }

    @objc private func toggleDockShortcuts() {
        ConfigStore.shared.update { $0.dockShortcuts.toggle() }
    }

    @objc private func toggleClipboardHistory() {
        ConfigStore.shared.update { $0.clipboardHistory.toggle() }
        syncClipboardStore()
    }

    @objc private func clearClipboardHistory() {
        ClipboardStore.shared.clear()
    }

    /// 配置里开关剪贴板历史时，同步启动 / 停止轮询
    private func syncClipboardStore() {
        if config.clipboardHistory {
            ClipboardStore.shared.start()
        } else {
            ClipboardStore.shared.stop()
        }
    }

    @objc private func runBinding(_ sender: NSMenuItem) {
        guard let title = sender.representedObject as? String,
              let binding = KeyTable.winBindings.first(where: { $0.title == title })
        else { return }
        binding.run()
    }

    @objc private func openConfig() {
        ConfigStore.shared.save()
        NSWorkspace.shared.open(ConfigStore.shared.fileURL)
    }

    @objc private func reloadConfig() {
        ConfigStore.shared.load()
        configDate = fileModificationDate()
        refreshIcon()
        syncClipboardStore()
    }

    @objc private func restartTap() {
        keyTap.start()
        refreshIcon()
    }

    @objc private func openLog() {
        Log.write("用户打开了日志")
        NSWorkspace.shared.open(Log.url)
    }

    @objc private func requestAccessibility() {
        Permissions.requestPromptThenOpenSettings()
    }

    /// 清掉旧授权记录并重新注册（跑过 make regrant 或换过签名后用）
    @objc private func reregister() {
        Permissions.reset()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            Permissions.requestPrompt()
        }
    }

    @objc private func showOnboarding() {
        OnboardingController.shared.show()
    }

    @objc private func openAppFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 外部修改配置

    private func setupConfigWatch() {
        configDate = fileModificationDate()
        let timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.reloadIfChanged()
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func fileModificationDate() -> Date? {
        try? FileManager.default.attributesOfItem(atPath: ConfigStore.shared.fileURL.path)[.modificationDate] as? Date
    }

    private func reloadIfChanged() {
        let current = fileModificationDate()
        guard current != configDate else { return }
        configDate = current
        ConfigStore.shared.load()
        refreshIcon()
        syncClipboardStore()
    }

    /// 没有授权就弹首次启动引导窗口（比裸的系统弹框更容易讲清楚怎么做）
    private func showOnboardingIfNeeded() {
        // --onboarding 参数用于单独调试引导窗口（即使已授权也强制显示）
        let force = CommandLine.arguments.contains("--onboarding")
        guard !Permissions.isTrusted || force else { return }
        // 等菜单栏图标出来再弹，视觉上更连贯
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            OnboardingController.shared.show()
        }
    }
}
