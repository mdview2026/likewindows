import CoreGraphics

struct Binding {
    enum Category {
        case general, window, dock, clipboard, search
    }

    let keyCode: CGKeyCode
    /// 除 Win/Alt 之外还需要的修饰键（精确匹配，避免 Win+Shift+← 命中 Win+←）
    let modifiers: CGEventFlags
    let title: String
    var category: Category = .general
    let run: () -> Void
}

enum KeyTable {
    static let modifierMask: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]

    /// 数字键 1…9 的虚拟键码
    private static let digitKeyCodes: [CGKeyCode] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    private static let dockBindings: [Binding] = digitKeyCodes.enumerated().map { index, keyCode in
        Binding(keyCode: keyCode,
                modifiers: [],
                title: "Win+\(index + 1) Dock 第 \(index + 1) 个应用",
                category: .dock,
                run: { Actions.activateDockApp(index) })
    }

    static let winBindings: [Binding] = [
        Binding(keyCode: 48,  modifiers: [],            title: "Win+Tab 任务视图",      run: Actions.taskView),
        Binding(keyCode: 2,   modifiers: [],            title: "Win+D 显示桌面",        run: Actions.showDesktop),
        Binding(keyCode: 14,  modifiers: [],            title: "Win+E 资源管理器",      run: Actions.openFileManager),
        Binding(keyCode: 37,  modifiers: [],            title: "Win+L 锁屏",            run: Actions.lockScreen),
        Binding(keyCode: 46,  modifiers: [],            title: "Win+M 最小化窗口",      category: .window, run: Actions.minimizeWindow),
        Binding(keyCode: 126, modifiers: [],            title: "Win+↑ 最大化",          category: .window, run: Actions.maximizeWindow),
        Binding(keyCode: 125, modifiers: [],            title: "Win+↓ 还原/最小化",     category: .window, run: Actions.restoreOrMinimizeWindow),
        Binding(keyCode: 123, modifiers: [],            title: "Win+← 左半屏",          category: .window, run: Actions.snapLeft),
        Binding(keyCode: 124, modifiers: [],            title: "Win+→ 右半屏",          category: .window, run: Actions.snapRight),
        Binding(keyCode: 123, modifiers: .maskShift,    title: "Win+Shift+← 移到左屏",  category: .window, run: Actions.moveToLeftScreen),
        Binding(keyCode: 124, modifiers: .maskShift,    title: "Win+Shift+→ 移到右屏",  category: .window, run: Actions.moveToRightScreen),
        Binding(keyCode: 123, modifiers: .maskControl,  title: "Win+Ctrl+← 上个桌面",   category: .window, run: Actions.previousSpace),
        Binding(keyCode: 124, modifiers: .maskControl,  title: "Win+Ctrl+→ 下个桌面",   category: .window, run: Actions.nextSpace),
        Binding(keyCode: 1,   modifiers: [],            title: "Win+S 搜索",            category: .search, run: Actions.search),
        Binding(keyCode: 1,   modifiers: .maskShift,    title: "Win+Shift+S 截图",      category: .search, run: Actions.screenshotRegion),
        Binding(keyCode: 15,  modifiers: [],            title: "Win+R 运行(终端)",      run: Actions.run),
        Binding(keyCode: 12,  modifiers: [],            title: "Win+Q 退出应用",        run: Actions.quitApps),
        Binding(keyCode: 9,   modifiers: [],            title: "Win+V 剪贴板历史",      category: .clipboard, run: Actions.showClipboardHistory),
        Binding(keyCode: 9,   modifiers: .maskShift,    title: "Win+Shift+V 剪贴板历史", category: .clipboard, run: Actions.showClipboardHistory),
    ] + dockBindings

    static let altBindings: [Binding] = [
        Binding(keyCode: 48,  modifiers: [], title: "Alt+Tab 切换应用",   run: Actions.switchApp),
        Binding(keyCode: 118, modifiers: [], title: "Alt+F4 关闭窗口",    run: Actions.closeWindow),
    ]

    /// 按配置过滤后真正生效的 Win 组合。
    ///
    /// Windows 键盘上 Win 键就是 ⌘，所以这些组合会和 macOS 常用快捷键直接撞车：
    ///   ⌘V 粘贴、⌘S 保存、⌘⇧S 存储为…
    /// 撞车的按默认让位给 macOS（粘贴 / 保存比「打开剪贴板面板」重要得多），
    /// 换成 Win+Shift+V 仍然可以调出剪贴板历史；搜索用原生的 ⌘Space 即可。
    static func activeWinBindings(for config: Config) -> [Binding] {
        let commandMode = config.winKey.consumesCommandKey
        return winBindings.filter { binding in
            switch binding.category {
            case .general:
                return true
            case .window:
                return config.snap
            case .dock:
                return config.dockShortcuts
            case .clipboard:
                guard config.clipboardHistory else { return false }
                // Win+V 让位给粘贴，改用 Win+Shift+V
                if commandMode, binding.keyCode == 9, binding.modifiers.isEmpty { return false }
                return true
            case .search:
                // ⌘S / ⌘⇧S 让位给保存、存储为…
                return !commandMode
            }
        }
    }

    static func winBinding(key: CGKeyCode, flags: CGEventFlags, config: Config) -> Binding? {
        var wanted = flags.intersection(modifierMask)
        wanted.remove(config.winKey.flag)
        return activeWinBindings(for: config).first { $0.keyCode == key && $0.modifiers == wanted }
    }

    static func altBinding(key: CGKeyCode, flags: CGEventFlags) -> Binding? {
        let wanted = flags.intersection(modifierMask).subtracting(.maskAlternate)
        return altBindings.first { $0.keyCode == key && $0.modifiers == wanted }
    }
}

extension WinKey {
    var isOption: Bool { self == .leftOption || self == .rightOption }
}
