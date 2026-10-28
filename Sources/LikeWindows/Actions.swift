import AppKit
import CoreGraphics

/// Windows 习惯动作的具体实现
enum Actions {
    // 常用虚拟键码
    enum Key {
        static let tab: CGKeyCode = 48
        static let space: CGKeyCode = 49
        static let up: CGKeyCode = 126
        static let down: CGKeyCode = 125
        static let left: CGKeyCode = 123
        static let right: CGKeyCode = 124
        static let keyW: CGKeyCode = 13
        static let keyQ: CGKeyCode = 12
        static let key4: CGKeyCode = 21
    }

    static var windows: WindowManager { .shared }

    // MARK: - Win + X

    /// Win+Tab：任务视图 / 调度中心
    static func taskView() {
        Synth.combo(Key.up, .maskControl)
    }

    /// Win+D：全部最小化 / 再按一次还原
    static func showDesktop() {
        windows.toggleShowDesktop()
    }

    /// Win+E：打开「资源管理器」→ Finder 主目录
    static func openFileManager() {
        Log.write("打开 Finder 主目录")
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
    }

    /// Win+L：锁屏
    static func lockScreen() {
        Synth.combo(Key.keyQ, [.maskCommand, .maskControl])
    }

    /// Win+M：最小化当前窗口
    static func minimizeWindow() {
        windows.minimize()
    }

    /// Win+↑：最大化（填满工作区）
    static func maximizeWindow() {
        windows.maximize()
    }

    /// Win+↓：还原 / 最小化
    static func restoreOrMinimizeWindow() {
        windows.restoreOrMinimize()
    }

    /// Win+← / Win+→：左右贴边
    static func snapLeft() {
        windows.snap(.left)
    }

    static func snapRight() {
        windows.snap(.right)
    }

    /// Win+Shift+← / →：移到上一块 / 下一块显示器
    static func moveToLeftScreen() {
        windows.moveToNextScreen(-1)
    }

    static func moveToRightScreen() {
        windows.moveToNextScreen(1)
    }

    /// Win+Ctrl+← / →：切换虚拟桌面（macOS 空间）
    static func previousSpace() {
        Synth.combo(Key.left, .maskControl)
    }

    static func nextSpace() {
        Synth.combo(Key.right, .maskControl)
    }

    /// Win+S：搜索 → Spotlight
    static func search() {
        Synth.combo(Key.space, .maskCommand)
    }

    /// Win+R：运行 → 终端
    static func run() {
        Synth.open("/System/Applications/Utilities/Terminal.app")
    }

    /// Win+Shift+S：区域截图
    static func screenshotRegion() {
        Synth.combo(Key.key4, [.maskCommand, .maskShift])
    }

    /// Win+Q：退出当前应用
    static func quitApps() {
        Synth.combo(Key.keyQ, .maskCommand)
    }

    /// 单独轻按 Win 键：开始菜单 → 启动台 / Apps
    static func startMenu() {
        let candidates = [
            "/System/Applications/Apps.app",
            "/System/Applications/Launchpad.app",
            "/System/Applications/Mission Control.app",
        ]
        if let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            Synth.open(path)
        } else {
            Synth.combo(Key.space, .maskCommand)
        }
    }

    /// Win+1…9：切换 Dock 上第 n 个应用（已在前台则循环它的窗口）
    static func activateDockApp(_ index: Int) {
        DockApps.activate(index: index)
    }

    /// Win+V：剪贴板历史面板
    static func showClipboardHistory() {
        ClipboardPanelController.shared.toggle()
    }

    // MARK: - Alt 系列（Windows 上 Alt 的用法）

    /// Alt+Tab：切换应用
    static func switchApp() {
        Synth.combo(Key.tab, .maskCommand, delay: 0.02)
    }

    /// Alt+F4：关闭窗口
    static func closeWindow() {
        Synth.combo(Key.keyW, .maskCommand, delay: 0.02)
    }
}
