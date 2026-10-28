import AppKit

// ---- 无界面模式：必须在 NSApplication 启动前处理，否则会进主循环不返回 ----
if CommandLine.arguments.contains("--selftest") {
    exit(SelfTest.run())
}

if let index = CommandLine.arguments.firstIndex(of: "--do"),
   CommandLine.arguments.count > index + 1 {
    exit(SelfTest.perform(CommandLine.arguments[index + 1]))
}

// ---- 正常启动（菜单栏 App）----
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
