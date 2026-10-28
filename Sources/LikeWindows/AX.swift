import AppKit
import ApplicationServices

/// AXUIElement 读写封装 + 坐标换算。
///
/// 坐标系差异：AX 使用「主屏左上角为原点、y 向下」；NSScreen 使用
/// 「左下角为原点、y 向上」。换算必须以上屏（origin == .zero 的那块）为基准。
enum AX {
    static let system = AXUIElementCreateSystemWide()

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? Bool
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as! AXUIElement?
    }

    static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return []
        }
        return (value as? [AXUIElement]) ?? []
    }

    static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value as! AXValue?,
              AXValueGetType(axValue) == .cgPoint
        else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value as! AXValue?,
              AXValueGetType(axValue) == .cgSize
        else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    @discardableResult
    static func setBool(_ element: AXUIElement, _ attribute: String, _ value: Bool) -> Bool {
        AXUIElementSetAttributeValue(element, attribute as CFString, value as CFBoolean) == .success
    }

    @discardableResult
    static func setPoint(_ element: AXUIElement, _ attribute: String, _ value: CGPoint) -> Bool {
        var point = value
        guard let axValue = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axValue) == .success
    }

    @discardableResult
    static func setSize(_ element: AXUIElement, _ attribute: String, _ value: CGSize) -> Bool {
        var size = value
        guard let axValue = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axValue) == .success
    }

    // MARK: - 窗口

    /// 当前前台窗口
    static func focusedWindow() -> AXUIElement? {
        var appRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &appRef) == .success,
           let appElement = appRef as! AXUIElement? {
            if let window = element(appElement, kAXFocusedWindowAttribute) {
                return window
            }
        }
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(front.processIdentifier)
        if let window = element(appElement, kAXFocusedWindowAttribute) {
            return window
        }
        return elements(appElement, kAXWindowsAttribute).first
    }

    /// 窗口在 NSScreen 坐标系中的 frame
    static func frame(of window: AXUIElement) -> NSRect? {
        guard let origin = point(window, kAXPositionAttribute),
              let size = size(window, kAXSizeAttribute)
        else { return nil }
        return NSRect(x: origin.x,
                      y: Space.primaryHeight - origin.y - size.height,
                      width: size.width,
                      height: size.height)
    }

    /// 设置窗口 frame（先尺寸、后位置，避免贴边时被系统裁剪）
    @discardableResult
    static func setFrame(_ window: AXUIElement, _ rect: NSRect) -> Bool {
        let axOrigin = CGPoint(x: rect.minX, y: Space.primaryHeight - rect.maxY)
        _ = setSize(window, kAXSizeAttribute, rect.size)
        _ = setPoint(window, kAXPositionAttribute, axOrigin)
        _ = setSize(window, kAXSizeAttribute, rect.size)
        _ = setPoint(window, kAXPositionAttribute, axOrigin)
        return true
    }

    static func isFullScreen(_ window: AXUIElement) -> Bool {
        bool(window, "AXFullScreen") ?? false
    }
}

/// 屏幕 / 坐标换算工具
enum Space {
    /// 主屏（含菜单栏、origin 为 .zero 的那块）高度
    static var primaryHeight: CGFloat {
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return primary.frame.height
        }
        return NSScreen.screens.first?.frame.height ?? 0
    }

    static func screen(containing nsRect: NSRect) -> NSScreen? {
        let probe = NSPoint(x: nsRect.midX, y: nsRect.midY)
        if let hit = NSScreen.screens.first(where: { $0.frame.contains(probe) }) {
            return hit
        }
        // 窗口很可能跨屏或超出边界，退化为「重叠面积最大」
        return NSScreen.screens.max { a, b in
            a.frame.intersection(nsRect).area < b.frame.intersection(nsRect).area
        } ?? NSScreen.main
    }

    static func screenIndex(of screen: NSScreen) -> Int? {
        NSScreen.screens.firstIndex { $0 === screen }
    }

    /// 相邻屏幕（按屏幕在列表中的顺序，即用户拖拽排布顺序）
    static func neighborScreen(of screen: NSScreen, offset: Int) -> NSScreen? {
        guard let index = screenIndex(of: screen) else { return nil }
        let target = index + offset
        guard NSScreen.screens.indices.contains(target) else { return nil }
        return NSScreen.screens[target]
    }
}

extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
