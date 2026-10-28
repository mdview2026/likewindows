import AppKit
import ApplicationServices

private func keyTapCallback(proxy: CGEventTapProxy,
                            type: CGEventType,
                            event: CGEvent,
                            refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}

/// 全局键盘监听（CGEventTap）
final class KeyTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    private var winDown = false
    private var winUsed = false
    private var winPressedAt: TimeInterval = 0
    /// 已被拦截的 keyDown，配对的 keyUp 也要吞掉
    private var swallowed = Set<CGKeyCode>()

    private(set) var isRunning = false
    private var failureCount = 0
    /// 诊断模式：在时间点之前把所有按键事件写进日志
    var debugLogUntil: Date?
    var onAvailabilityChange: (() -> Void)?

    var hasAccessibility: Bool { AXIsProcessTrusted() }

    @discardableResult
    func start() -> Bool {
        stop()

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: keyTapCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            failureCount += 1
            if failureCount == 1 || failureCount % 30 == 0 {
                Log.write("事件监听创建失败 x\(failureCount)：没有辅助功能权限 (trusted=\(AXIsProcessTrusted()))")
            }
            isRunning = false
            onAvailabilityChange?()
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.source = source
        isRunning = true
        failureCount = 0
        Log.write("事件监听已启动，Win 键 = \(ConfigStore.shared.value.winKey.rawValue)")
        onAvailabilityChange?()
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        winDown = false
        swallowed.removeAll()
        if isRunning {
            isRunning = false
            onAvailabilityChange?()
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passthrough = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            let reason = type == .tapDisabledByTimeout ? "超时" : "用户输入"
            Log.write("事件监听被系统关闭（\(reason)），正在重新启用")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return passthrough
        }

        // 忽略自己合成的按键，避免死循环
        if event.getIntegerValueField(.eventSourceUserData) == Synth.marker {
            return passthrough
        }

        guard type == .keyDown || type == .keyUp || type == .flagsChanged else { return passthrough }

        let config = ConfigStore.shared.value
        guard config.enabled else { return passthrough }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        switch type {
        case .flagsChanged:
            logIfDebugging(type: type, keyCode: keyCode, event: event)
            if config.winKey.matches(keyCode) {
                let isDown = event.flags.contains(config.winKey.flag)
                if isDown, !winDown {
                    winDown = true
                    winUsed = false
                    winPressedAt = ProcessInfo.processInfo.systemUptime
                } else if !isDown, winDown {
                    // 任意 ⌘ 模式下，另一侧 ⌘ 可能还按着
                    if config.winKey == .anyCommand, event.flags.contains(.maskCommand) {
                        return passthrough
                    }
                    winDown = false
                    let quickTap = ProcessInfo.processInfo.systemUptime - winPressedAt < 0.4
                    if !winUsed, quickTap, config.tapForStartMenu {
                        DispatchQueue.main.async { Actions.startMenu() }
                    }
                }
            }
            return passthrough

        case .keyDown:
            logIfDebugging(type: type, keyCode: keyCode, event: event)
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
                return swallowed.contains(keyCode) ? nil : passthrough
            }

            if winDown {
                winUsed = true
                if let binding = KeyTable.winBinding(key: keyCode, flags: event.flags, config: config) {
                    Log.write("触发 \(binding.title)")
                    swallowed.insert(keyCode)
                    DispatchQueue.main.async { binding.run() }
                    return nil
                }
                return passthrough
            }

            if config.altTab, !config.winKey.isOption, event.flags.contains(.maskAlternate),
               let binding = KeyTable.altBinding(key: keyCode, flags: event.flags) {
                swallowed.insert(keyCode)
                DispatchQueue.main.async { binding.run() }
                return nil
            }
            return passthrough

        case .keyUp:
            return swallowed.remove(keyCode) != nil ? nil : passthrough

        default:
            return passthrough
        }
    }

    private func logIfDebugging(type: CGEventType, keyCode: CGKeyCode, event: CGEvent) {
        guard let until = debugLogUntil, Date() < until else { return }
        let kind = type == .keyDown ? "按下" : "修饰键"
        let flags = event.flags.intersection(KeyTable.modifierMask)
        var names: [String] = []
        if flags.contains(.maskCommand) { names.append("⌘") }
        if flags.contains(.maskAlternate) { names.append("⌥") }
        if flags.contains(.maskControl) { names.append("⌃") }
        if flags.contains(.maskShift) { names.append("⇧") }
        Log.write("按键诊断：\(kind) keyCode=\(keyCode) 修饰=[\(names.joined())]")
    }
}
