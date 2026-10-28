import AppKit

/// 读取 Dock 上固定的 App，用于 Win+1…9
enum DockApps {
    struct Item {
        let name: String
        let bundleID: String?
        let url: URL?
    }

    static func pinned() -> [Item] {
        guard let prefs = UserDefaults(suiteName: "com.apple.dock"),
              let apps = prefs.array(forKey: "persistent-apps") as? [[String: Any]]
        else { return [] }

        return apps.compactMap { entry -> Item? in
            guard let tile = entry["tile-data"] as? [String: Any] else { return nil }
            let name = (tile["file-label"] as? String) ?? ""

            var url: URL?
            if let fileData = tile["file-data"] as? [String: Any],
               let path = fileData["_CFURLString"] as? String {
                url = URL(string: path) ?? URL(fileURLWithPath: path)
            }
            let bundleID = tile["bundle-identifier"] as? String

            guard bundleID != nil || url != nil else { return nil }
            // 过滤文件夹 / 废纸篓之类的非 App 项（有 bundle id 但没名字的也算 App）
            if url == nil, bundleID == nil { return nil }
            return Item(name: name, bundleID: bundleID, url: url)
        }
    }

    /// 激活第 index 个（0 起）。已经在前台就循环它的窗口，对齐 Windows 的任务栏行为。
    static func activate(index: Int) {
        let items = pinned()
        guard items.indices.contains(index) else {
            Log.write("Win+\(index + 1)：Dock 上没有第 \(index + 1) 个应用")
            return
        }
        let item = items[index]

        if let front = NSWorkspace.shared.frontmostApplication,
           let bundleID = item.bundleID,
           front.bundleIdentifier == bundleID {
            Log.write("Win+\(index + 1)：\(item.name) 已在前台，循环窗口")
            Synth.combo(50, .maskCommand)  // ⌘`
            return
        }

        if let bundleID = item.bundleID,
           let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            Log.write("Win+\(index + 1)：激活 \(item.name)")
            activate(running)
            return
        }

        if let url = item.url {
            Log.write("Win+\(index + 1)：启动 \(item.name)")
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error { Log.write("启动失败：\(error.localizedDescription)") }
            }
            return
        }

        if let bundleID = item.bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    static func activate(_ app: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [])
        }
    }
}
