import AppKit

/// `LikeWindows --selftest`：打印权限、Dock 解析、剪贴板监听状态，然后退出。
enum SelfTest {
    /// `--do <关键字>`：手动触发一个 Win 组合（用来单独验证某个动作）
    static func perform(_ keyword: String) -> Int32 {
        ConfigStore.shared.load()
        let all = KeyTable.activeWinBindings(for: ConfigStore.shared.value)
        guard let binding = all.first(where: { $0.title.localizedCaseInsensitiveContains(keyword) }) else {
            print("没有匹配到动作。可用：")
            all.forEach { print("  \($0.title)") }
            return 1
        }
        print("执行：\(binding.title)（辅助功能权限：\(AXIsProcessTrusted() ? "已授权" : "未授权")）")
        binding.run()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        print("完成")
        return 0
    }

    static func run() -> Int32 {
        print("== LikeWindows 自检 ==")
        print("辅助功能权限：\(AXIsProcessTrusted() ? "已授权" : "未授权（Win 组合键不会生效）")")
        ConfigStore.shared.load()
        print("Win 键：\(ConfigStore.shared.value.winKey.displayName)")
        print("配置文件：\(ConfigStore.shared.fileURL.path)")

        let dock = DockApps.pinned()
        print("\nDock 固定应用（Win+1…9）：\(dock.count) 个")
        for (index, item) in dock.prefix(9).enumerated() {
            print("  Win+\(index + 1)  \(item.name.isEmpty ? "(无名)" : item.name)  "
                  + "bundle=\(item.bundleID ?? "-")  "
                  + "path=\(item.url?.path ?? "-")")
        }

        print("\n剪贴板监听：采样 2 秒（期间可复制任意文本）…")
        ClipboardStore.shared.start()
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        print("  记录到 \(ClipboardStore.shared.items.count) 条")
        for item in ClipboardStore.shared.items.prefix(3) {
            print("  · \(item.preview.prefix(60))  [\(item.relativeTime)]")
        }

        let bindings = KeyTable.activeWinBindings(for: ConfigStore.shared.value)
        print("\n生效的 Win 组合：\(bindings.count) 个")
        for binding in bindings {
            print("  \(binding.title)")
        }
        print("\n自检结束")
        return 0
    }
}
