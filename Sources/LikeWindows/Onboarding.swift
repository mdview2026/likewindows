import AppKit

/// 步骤序号圆点
private final class StepBadge: NSView {
    private let number: Int

    init(_ number: Int) {
        self.number = number
        super.init(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 20),
            heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
        NSColor.controlAccentColor.setFill()
        circle.fill()

        let text = "\(number)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                              y: (bounds.height - size.height) / 2),
                  withAttributes: attributes)
    }
}

/// 圆角浅色容器（NSBox + contentView 在纯 autolayout 下拿不到高度）
private final class RoundedBox: NSView {
    private let fill: NSColor

    init(fill: NSColor) {
        self.fill = fill
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateLayer() {
        layer?.backgroundColor = fill.cgColor
    }
}

/// 当前授权状态卡片
private final class StatusCard: NSView {
    private let dot = NSView()
    private let label = NSTextField(labelWithString: "")
    private var isTrusted = false

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        translatesAutoresizingMaskIntoConstraints = false

        dot.wantsLayer = true
        dot.layer?.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(dot)
        addSubview(label)
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 11),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -11),
        ])
        update(trusted: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    func update(trusted: Bool) {
        isTrusted = trusted
        let color: NSColor = trusted ? .systemGreen : .systemOrange
        dot.layer?.backgroundColor = color.cgColor
        label.stringValue = trusted ? "已授权，功能已生效" : "尚未授权 —— 现在按 Win 组合键不会有任何反应"
        label.textColor = trusted ? .labelColor : .secondaryLabelColor
    }
}

/// 首次启动的引导窗口
final class OnboardingController: NSObject, NSWindowDelegate {
    static let shared = OnboardingController()

    private var window: NSWindow?
    private var statusCard: StatusCard?
    private var timer: Timer?
    private var shownAt: Date = .distantPast
    private var willAutoClose = false
    private var stackView: NSStackView?

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            startPolling()
            return
        }
        build()
        guard let window else { return }
        shownAt = Date()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        startPolling()
        window.contentView?.layoutSubtreeIfNeeded()
        let size = window.contentLayoutRect.size
        Log.write("引导窗口已显示（\(Int(size.width))x\(Int(size.height))，trusted=\(Permissions.isTrusted)）")

    }

    func close() {
        willAutoClose = false
        timer?.invalidate()
        timer = nil
        window?.close()
        window = nil
    }

    // MARK: - 界面

    /// 自动换行的标签：必须显式给出排版宽度，否则算出来的高度是单行高度
    private func wrappingLabel(_ text: String, width: CGFloat,
                               font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = color
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = width
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // 加到普通容器（非 NSStackView）里时必须关掉 autoresizing，否则约束不生效
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func build() {
        let content = NSView()
        let innerWidth: CGFloat = 460 - 64
        content.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage ?? NSImage(systemSymbolName: "rectangle.split.2x1",
                                                           accessibilityDescription: nil)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let title = NSTextField(labelWithString: "还差一步就能用了")
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.alignment = .center

        let subtitle = wrappingLabel(
            "LikeWindows 需要「辅助功能」权限，才能监听键盘、贴边分屏、显示桌面。"
            + "这个权限只用于本地操作，不会读取你的内容。",
            width: innerWidth, font: .systemFont(ofSize: 13), color: .secondaryLabelColor)
        subtitle.alignment = .center

        let card = StatusCard()
        statusCard = card

        let steps = NSStackView(views: [
            stepRow(1, "点下面的「打开系统设置」，会跳到 **隐私与安全性 → 辅助功能**。"),
            stepRow(2, "在列表里打开 **LikeWindows** 的开关。列表里没有它？点左下角的 ＋ 手动选择，"
                     + "或把应用从访达拖进列表。"),
            stepRow(3, "回到这个窗口，状态会自动变成「已授权」，不用重启。"),
        ])
        steps.orientation = .vertical
        steps.alignment = .leading
        steps.spacing = 14

        let tip = wrappingLabel(
            "用的是 Windows 键盘？授权后记得在菜单栏图标里选择"
            + "「键盘：Windows 键盘（Win 键 = ⌘）」，否则 Win 键会被当成 ⌘。",
            width: innerWidth - 22, font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)

        let tipBox = RoundedBox(fill: NSColor.quaternaryLabelColor.withAlphaComponent(0.35))
        tipBox.addSubview(tip)
        NSLayoutConstraint.activate([
            tip.topAnchor.constraint(equalTo: tipBox.topAnchor, constant: 9),
            tip.bottomAnchor.constraint(equalTo: tipBox.bottomAnchor, constant: -9),
            tip.leadingAnchor.constraint(equalTo: tipBox.leadingAnchor, constant: 11),
            tip.trailingAnchor.constraint(equalTo: tipBox.trailingAnchor, constant: -11),
        ])

        let openButton = NSButton(title: "打开系统设置", target: self, action: #selector(openSettings))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"
        openButton.controlSize = .large

        let checkButton = NSButton(title: "我已授权，重新检查", target: self, action: #selector(recheck))
        checkButton.bezelStyle = .rounded
        checkButton.controlSize = .large

        let laterButton = NSButton(title: "稍后", target: self, action: #selector(dismiss))
        laterButton.bezelStyle = .rounded
        laterButton.controlSize = .large

        let buttons = NSStackView(views: [openButton, checkButton, laterButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.distribution = .fillEqually

        let footer = NSTextField(labelWithString: "剪贴板历史只保存在内存里 · 不联网 · 不收集任何数据")
        footer.font = .systemFont(ofSize: 10.5)
        footer.textColor = .tertiaryLabelColor
        footer.alignment = .center

        let stack = NSStackView(views: [icon, title, subtitle, card, steps, tipBox, buttons, footer])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.setCustomSpacing(6, after: icon)
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(20, after: subtitle)
        stack.setCustomSpacing(22, after: card)
        stack.setCustomSpacing(20, after: steps)
        stack.setCustomSpacing(22, after: tipBox)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        let width: CGFloat = 460
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            card.widthAnchor.constraint(equalToConstant: width - 64),
            steps.widthAnchor.constraint(equalToConstant: width - 64),
            tipBox.widthAnchor.constraint(equalToConstant: width - 64),
            buttons.widthAnchor.constraint(equalToConstant: width - 64),
            subtitle.widthAnchor.constraint(equalToConstant: width - 64),
            footer.widthAnchor.constraint(equalToConstant: width - 64),
        ])

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 560),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.title = "LikeWindows 设置"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.contentView = content
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.level = .normal
        // 先按目标宽度布局一次，再按内容实际需要的高度定窗口高度
        // （换行标签必须先有宽度才能算出高度）
        window.setContentSize(NSSize(width: width, height: 640))
        window.contentView?.layoutSubtreeIfNeeded()
        let contentHeight = stack.fittingSize.height + 28 + 24
        window.setContentSize(NSSize(width: width, height: contentHeight))

        self.window = window
        self.stackView = stack
    }

    private func stepRow(_ index: Int, _ markdown: String) -> NSView {
        let textWidth: CGFloat = 460 - 64 - 30
        let label = wrappingLabel("", width: textWidth, font: .systemFont(ofSize: 12.5))
        label.attributedStringValue = markdownText(markdown)

        let row = NSStackView(views: [StepBadge(index), label])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        label.widthAnchor.constraint(equalToConstant: textWidth).isActive = true
        return row
    }

    /// 极简 markdown：**加粗**
    private func markdownText(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let base = NSFont.systemFont(ofSize: 12.5)
        let bold = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        var isBold = false
        for chunk in text.components(separatedBy: "**") {
            guard !chunk.isEmpty else { isBold.toggle(); continue }
            result.append(NSAttributedString(string: chunk, attributes: [
                .font: isBold ? bold : base,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
            ]))
            isBold.toggle()
        }
        return result
    }

    // MARK: - 状态轮询

    private func startPolling() {
        poll()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let trusted = Permissions.isTrusted
        statusCard?.update(trusted: trusted)
        // 观察者回调里关窗口太早会打断动画，稍微延迟
        if trusted, !willAutoClose, Date().timeIntervalSince(shownAt) > 1.5 {
            willAutoClose = true
            Log.write("引导窗口：检测到授权已生效，自动关闭")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.close()
            }
        }
    }

    // MARK: - 动作

    @objc private func openSettings() {
        Permissions.requestPromptThenOpenSettings()
    }

    @objc private func recheck() {
        statusCard?.update(trusted: Permissions.isTrusted)
        if Permissions.isTrusted { close() }
    }

    @objc private func dismiss() {
        Log.write("引导窗口：用户选择稍后")
        close()
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
    }
}
