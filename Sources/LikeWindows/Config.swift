import Foundation
import CoreGraphics

/// 哪一颗物理按键充当「Win 键」。
enum WinKey: String, Codable, CaseIterable {
    /// Windows 键盘的 Win 键：左右两侧 ⌘ 都算
    case anyCommand
    case rightCommand
    case leftCommand
    case leftOption
    case rightOption
    case leftControl
    case rightControl

    var keyCode: CGKeyCode {
        switch self {
        case .anyCommand:   return 55
        case .rightCommand: return 54
        case .leftCommand:  return 55
        case .leftOption:   return 58
        case .rightOption:  return 61
        case .leftControl:  return 59
        case .rightControl: return 62
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .anyCommand, .rightCommand, .leftCommand: return .maskCommand
        case .leftOption, .rightOption:          return .maskAlternate
        case .leftControl, .rightControl:        return .maskControl
        }
    }

    var displayName: String {
        switch self {
        case .anyCommand:   return "任意 ⌘（Windows 键盘的 Win 键）"
        case .rightCommand: return "右侧 ⌘ (Mac 键盘推荐)"
        case .leftCommand:  return "左侧 ⌘"
        case .leftOption:   return "左侧 ⌥"
        case .rightOption:  return "右侧 ⌥"
        case .leftControl:  return "左侧 ⌃"
        case .rightControl: return "右侧 ⌃"
        }
    }
}

extension WinKey {
    /// 这颗物理键是不是「Win 键」
    func matches(_ keyCode: CGKeyCode) -> Bool {
        switch self {
        case .anyCommand:   return keyCode == 54 || keyCode == 55
        default:            return keyCode == self.keyCode
        }
    }

    /// Win 键本身就占用了 ⌘（Windows 键盘）
    var consumesCommandKey: Bool {
        self == .anyCommand || self == .leftCommand || self == .rightCommand
    }
}

struct Config: Codable {
    var enabled: Bool = true
    var winKey: WinKey = .rightCommand
    /// Alt+Tab 切换应用 / Alt+F4 关闭窗口
    var altTab: Bool = true
    /// 单独轻按 Win 键 → 打开启动台（macOS 26 为「Apps」）
    var tapForStartMenu: Bool = true
    /// Win 方向键贴边分屏 / 最大化
    var snap: Bool = true
    /// Win+1…9 切换 Dock 上第 n 个应用
    var dockShortcuts: Bool = true
    /// Win+V 剪贴板历史
    var clipboardHistory: Bool = true

    init() {}

    // 容忍缺失字段：老版本配置文件不会让新字段解码失败
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        // 用字符串解码：新版本增加的枚举值在旧版本里读不懂时，只回退这一项，
        // 而不是整份配置解码失败
        if let raw = try c.decodeIfPresent(String.self, forKey: .winKey),
           let key = WinKey(rawValue: raw) {
            winKey = key
        }
        altTab = try c.decodeIfPresent(Bool.self, forKey: .altTab) ?? d.altTab
        tapForStartMenu = try c.decodeIfPresent(Bool.self, forKey: .tapForStartMenu) ?? d.tapForStartMenu
        snap = try c.decodeIfPresent(Bool.self, forKey: .snap) ?? d.snap
        dockShortcuts = try c.decodeIfPresent(Bool.self, forKey: .dockShortcuts) ?? d.dockShortcuts
        clipboardHistory = try c.decodeIfPresent(Bool.self, forKey: .clipboardHistory) ?? d.clipboardHistory
    }
}

/// 配置读写：~/.config/likewindows/config.json
final class ConfigStore {
    static let shared = ConfigStore()

    private(set) var value = Config()
    private var observers: [() -> Void] = []

    var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/likewindows/config.json")
    }

    private init() {}

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(Config.self, from: data)
        else {
            value = Config()
            return
        }
        value = decoded
        notify()
    }

    func save() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: fileURL, options: .atomic)
        notify()
    }

    func update(_ mutate: (inout Config) -> Void) {
        mutate(&value)
        save()
    }

    func onChange(_ block: @escaping () -> Void) {
        observers.append(block)
    }

    private func notify() {
        observers.forEach { $0() }
    }
}
