import AppKit
import ApplicationServices

/// 窗口级操作：贴边、最大化、最小化、显示桌面、跨屏移动。
final class WindowManager {
    static let shared = WindowManager()

    /// 最大化前的原始 frame，用于「向下」还原
    private var restoreFrames: [String: NSRect] = [:]

    private var desktopHidden = false
    private var hiddenApps = false
    private var hiddenWindows: [AXUIElement] = []

    private init() {}

    // MARK: - 前台窗口

    struct Target {
        let window: AXUIElement
        let screen: NSScreen
        let frame: NSRect
    }

    func target() -> Target? {
        guard let window = AX.focusedWindow(), let frame = AX.frame(of: window) else { return nil }
        guard let screen = Space.screen(containing: frame) else { return nil }
        return Target(window: window, screen: screen, frame: frame)
    }

    private func key(for window: AXUIElement) -> String {
        let pid = pid(of: window)
        let title = AX.string(window, kAXTitleAttribute) ?? ""
        return "\(pid)|\(title)"
    }

    private func pid(of window: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        return pid
    }

    // MARK: - 贴边分屏

    enum Side { case left, right }

    func snap(_ side: Side) {
        guard let target = target() else { return }
        let area = target.screen.visibleFrame
        let half = (area.width / 2).rounded(.down)

        // 已经贴在同一侧 → 再按一次循环到 2/3 宽度，模拟 Windows 的循环行为
        let leftRect = NSRect(x: area.minX, y: area.minY, width: half, height: area.height)
        let rightRect = NSRect(x: area.maxX - half, y: area.minY, width: half, height: area.height)
        let current = target.frame

        let targetRect: NSRect
        switch side {
        case .left:
            if abs(current.width - half) < 4 && abs(current.minX - area.minX) < 4 {
                targetRect = NSRect(x: area.minX, y: area.minY, width: area.width * 2 / 3, height: area.height)
            } else {
                targetRect = leftRect
            }
        case .right:
            if abs(current.width - half) < 4 && abs(current.maxX - area.maxX) < 4 {
                targetRect = NSRect(x: area.maxX - area.width * 2 / 3, y: area.minY,
                                    width: area.width * 2 / 3, height: area.height)
            } else {
                targetRect = rightRect
            }
        }
        AX.setFrame(target.window, targetRect)
    }

    /// Windows 的「最大化」= 填满工作区（不进入 macOS 全屏）
    func maximize() {
        guard let target = target() else { return }
        restoreFrames[key(for: target.window)] = target.frame
        AX.setFrame(target.window, target.screen.visibleFrame)
    }

    /// 最小化窗口
    func minimize() {
        guard let window = AX.focusedWindow() else { return }
        AX.setBool(window, kAXMinimizedAttribute, true)
    }

    /// 最大化 → 还原；否则最小化（对齐 Windows 的 Win+↓）
    func restoreOrMinimize() {
        guard let target = target() else { return }
        let area = target.screen.visibleFrame
        let isMaximized = abs(target.frame.width - area.width) < 4
            && abs(target.frame.height - area.height) < 4
            && abs(target.frame.minX - area.minX) < 4

        if isMaximized, let saved = restoreFrames[key(for: target.window)] {
            AX.setFrame(target.window, saved)
            restoreFrames.removeValue(forKey: key(for: target.window))
        } else if isMaximized {
            // 没有记录（例如重启后），还原为屏幕 70% 居中
            let width = (area.width * 0.7).rounded()
            let height = (area.height * 0.7).rounded()
            AX.setFrame(target.window, NSRect(x: area.midX - width / 2,
                                              y: area.midY - height / 2,
                                              width: width, height: height))
        } else {
            AX.setBool(target.window, kAXMinimizedAttribute, true)
        }
    }

    /// 把窗口按相同相对位置移动到相邻显示器
    func moveToNextScreen(_ offset: Int) {
        guard let target = target(),
              let neighbor = Space.neighborScreen(of: target.screen, offset: offset)
        else { return }

        let from = target.screen.visibleFrame
        let to = neighbor.visibleFrame
        let ratioX = from.width > 0 ? (target.frame.minX - from.minX) / from.width : 0
        let ratioW = from.width > 0 ? target.frame.width / from.width : 1
        let ratioY = from.height > 0 ? (target.frame.minY - from.minY) / from.height : 0
        let ratioH = from.height > 0 ? target.frame.height / from.height : 1

        let width = min(max(to.width * ratioW, 200), to.width)
        let height = min(max(to.height * ratioH, 200), to.height)
        var x = to.minX + to.width * ratioX
        var y = to.minY + to.height * ratioY
        x = min(max(x, to.minX), to.maxX - width)
        y = min(max(y, to.minY), to.maxY - height)

        AX.setFrame(target.window, NSRect(x: x, y: y, width: width, height: height))
    }

    // MARK: - 显示桌面（Win+D）

    private func standardWindows() -> [(pid_t, AXUIElement)] {
        var result: [(pid_t, AXUIElement)] = []
        let selfPID = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  app.processIdentifier != selfPID
            else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            for window in AX.elements(appElement, kAXWindowsAttribute) {
                let subrole = AX.string(window, kAXSubroleAttribute)
                guard subrole == nil || subrole == "AXStandardWindow" else { continue }
                result.append((app.processIdentifier, window))
            }
        }
        return result
    }

    func toggleShowDesktop() {
        if hiddenApps {
            hiddenApps = false
            for app in NSWorkspace.shared.runningApplications where app.isHidden {
                app.unhide()
            }
            Log.write("显示桌面：已恢复隐藏的 App")
            return
        }
        if desktopHidden {
            for window in hiddenWindows {
                AX.setBool(window, kAXMinimizedAttribute, false)
            }
            hiddenWindows.removeAll()
            desktopHidden = false
            return
        }

        var hidden: [AXUIElement] = []
        let candidates = standardWindows()
        for (_, window) in candidates {
            // 有些 App 不实现 AXMinimized（返回 nil），只有明确为 true 才跳过
            guard AX.bool(window, kAXMinimizedAttribute) != true,
                  !AX.isFullScreen(window)
            else { continue }
            if AX.setBool(window, kAXMinimizedAttribute, true) {
                hidden.append(window)
            }
        }
        Log.write("显示桌面：候选窗口 \(candidates.count) 个，最小化成功 \(hidden.count) 个")

        // 一个都没成功 → 退化成「隐藏其他 App」，至少视觉上能看到桌面
        if hidden.isEmpty, !candidates.isEmpty {
            var hidCount = 0
            let selfPID = ProcessInfo.processInfo.processIdentifier
            for app in NSWorkspace.shared.runningApplications
            where app.activationPolicy == .regular && app.processIdentifier != selfPID {
                if app.hide() { hidCount += 1 }
            }
            Log.write("显示桌面：AX 最小化失败，改为隐藏 \(hidCount) 个 App")
            hiddenApps = hidCount > 0
            if hidCount > 0 { return }
        }

        hiddenWindows = hidden
        desktopHidden = !hidden.isEmpty
    }
}
