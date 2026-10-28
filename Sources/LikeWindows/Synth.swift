import AppKit
import CoreGraphics

/// 合成按键，用来触发 macOS 自带快捷键（Spotlight / Mission Control / 锁屏…）。
enum Synth {
    /// 用来标记「这是我们自己合成的按键」，事件监听里看到就放行，避免自触发
    static let marker: Int64 = 0x4C57_4C57  // "LWLW"

    static func combo(_ keyCode: CGKeyCode, _ flags: CGEventFlags = [], delay: TimeInterval = 0) {
        let post = {
            let source = CGEventSource(stateID: .hidSystemState)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            else { return }
            for event in [down, up] {
                event.flags = flags
                event.setIntegerValueField(.eventSourceUserData, value: marker)
                event.post(tap: .cghidEventTap)
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: post)
        } else {
            post()
        }
    }

    static func open(_ path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            Log.write("打开失败：路径不存在 \(path)")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path),
                                           configuration: configuration) { app, error in
            if let error {
                Log.write("打开 \(path) 失败：\(error.localizedDescription)")
            } else {
                Log.write("已打开 \(app?.localizedName ?? path)")
            }
        }
    }
}
