import AppKit

struct ClipItem {
    let id = UUID()
    let text: String
    let date: Date
    /// 单行预览
    var preview: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: " ⏎ ")
            .replacingOccurrences(of: "\n", with: " ⏎ ")
            .replacingOccurrences(of: "\t", with: " ")
    }

    var relativeTime: String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60) 分钟前" }
        if seconds < 86400 { return "\(seconds / 3600) 小时前" }
        return "\(seconds / 86400) 天前"
    }
}

/// 剪贴板历史：轮询 NSPasteboard.changeCount。
/// 只保留在内存里（退出即清空），并跳过密码管理器标记为「机密」的内容。
final class ClipboardStore {
    static let shared = ClipboardStore()

    static let limit = 50

    private(set) var items: [ClipItem] = []
    private var lastChangeCount = -1
    private var timer: Timer?
    private var observers: [() -> Void] = []

    private init() {}

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func onChange(_ block: @escaping () -> Void) {
        observers.append(block)
    }

    private func notify() {
        observers.forEach { $0() }
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        // 密码管理器之类会打上 Concealed / Transient 标记，不要记录
        let types = pasteboard.types ?? []
        let blocked: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
            NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
            NSPasteboard.PasteboardType("com.agilebits.onepassword"),
        ]
        guard !types.contains(where: blocked.contains) else { return }

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf8.count < 200_000
        else { return }

        record(text)
    }

    /// 我们自己往剪贴板写的（粘贴动作），不算新历史
    func record(_ text: String) {
        if let index = items.firstIndex(where: { $0.text == text }) {
            if index == 0 { return }
            let existing = items.remove(at: index)
            items.insert(ClipItem(text: existing.text, date: Date()), at: 0)
        } else {
            items.insert(ClipItem(text: text, date: Date()), at: 0)
        }
        if items.count > Self.limit {
            items.removeLast(items.count - Self.limit)
        }
        notify()
    }

    func clear() {
        items.removeAll()
        lastChangeCount = NSPasteboard.general.changeCount
        notify()
    }
}
