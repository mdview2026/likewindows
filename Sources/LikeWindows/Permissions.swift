import AppKit
import ApplicationServices

/// 辅助功能权限的统一入口
enum Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    /// 弹系统授权框。这个框同时会把 App「登记」进辅助功能列表，
    /// 所以必须真的调一次，光打开设置页是不够的。
    @discardableResult
    static func requestPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        Log.write("请求辅助功能授权，当前 trusted=\(trusted)")
        return trusted
    }

    static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }

    /// 先弹授权框，延迟再开设置页（顺序反了会顶掉授权框）
    static func requestPromptThenOpenSettings() {
        requestPrompt()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            openSettings()
        }
    }

    /// 清掉旧的授权记录（换签名后残留会挡住新授权）
    static func reset() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "Accessibility", "com.harryliang.likewindows"]
        try? task.run()
        task.waitUntilExit()
        Log.write("已重置辅助功能授权记录")
    }
}
