import AppKit

final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ClipCell: NSTableCellView {
    let previewField = NSTextField(labelWithString: "")
    let timeField = NSTextField(labelWithString: "")

    init(width: CGFloat) {
        super.init(frame: .zero)

        previewField.font = .systemFont(ofSize: 13)
        previewField.lineBreakMode = .byTruncatingTail
        previewField.maximumNumberOfLines = 1
        previewField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        previewField.translatesAutoresizingMaskIntoConstraints = false

        timeField.font = .systemFont(ofSize: 11)
        timeField.textColor = .secondaryLabelColor
        timeField.alignment = .right
        timeField.setContentHuggingPriority(.required, for: .horizontal)
        timeField.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(previewField)
        addSubview(timeField)
        textField = previewField

        NSLayoutConstraint.activate([
            previewField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            previewField.centerYAnchor.constraint(equalTo: centerYAnchor),
            timeField.leadingAnchor.constraint(equalTo: previewField.trailingAnchor, constant: 12),
            timeField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            timeField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

/// Win+V 弹出的剪贴板历史面板
final class ClipboardPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    static let shared = ClipboardPanelController()

    private static let panelSize = NSSize(width: 420, height: 360)

    private var panel: ClipboardPanel?
    private var searchField: NSSearchField?
    private var tableView: NSTableView?
    private var items: [ClipItem] = []
    private var previousApp: NSRunningApplication?
    private var isPasting = false
    private var shownAt: Date = .distantPast

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? hide(restoreFocus: true) : show()
    }

    // MARK: - 显示 / 隐藏

    func show() {
        buildIfNeeded()
        guard let panel, let searchField, let tableView else { return }

        previousApp = NSWorkspace.shared.frontmostApplication
        searchField.stringValue = ""
        refilter()
        tableView.scrollRowToVisible(0)

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        shownAt = Date()
        panel.setFrameOrigin(originNearMouse())
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        Log.write("剪贴板面板打开（\(items.count) 条）")
    }

    func hide(restoreFocus: Bool) {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        if restoreFocus, !isPasting, let previousApp {
            DockApps.activate(previousApp)
        }
        previousApp = nil
    }

    private func originNearMouse() -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = (screen ?? NSScreen.screens[0]).visibleFrame
        let size = panel?.frame.size ?? Self.panelSize
        let x = visible.midX - size.width / 2
        let y = visible.minY + 90
        return NSPoint(x: x.rounded(), y: y.rounded())
    }

    // MARK: - 构建界面

    private func buildIfNeeded() {
        guard panel == nil else { return }

        let panel = ClipboardPanel(contentRect: NSRect(origin: .zero, size: Self.panelSize),
                                   styleMask: [.borderless],
                                   backing: .buffered,
                                   defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false

        let search = NSSearchField()
        search.placeholderString = "搜索剪贴板历史…"
        search.font = .systemFont(ofSize: 13)
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false

        let table = NSTableView()
        table.style = .inset
        table.rowHeight = 34
        table.headerView = nil
        table.backgroundColor = .clear
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = false
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(doubleClickedRow)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(search)
        effect.addSubview(scroll)
        container.addSubview(effect)
        panel.contentView = container

        NSLayoutConstraint.activate([
            effect.topAnchor.constraint(equalTo: container.topAnchor),
            effect.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            effect.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            search.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            search.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            search.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -6),
            scroll.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -8),
        ])

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(panelResignedKey),
                                               name: NSWindow.didResignKeyNotification,
                                               object: panel)
        ClipboardStore.shared.onChange { [weak self] in
            guard let self, self.isVisible else { return }
            self.refilter()
        }

        self.panel = panel
        self.searchField = search
        self.tableView = table
    }

    @objc private func panelResignedKey() {
        guard Date().timeIntervalSince(shownAt) > 0.25 else { return }
        hide(restoreFocus: false)
    }

    // MARK: - 过滤

    private func refilter() {
        let query = (searchField?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let all = ClipboardStore.shared.items
        items = query.isEmpty
            ? all
            : all.filter { $0.text.localizedCaseInsensitiveContains(query) }

        tableView?.reloadData()
        if !items.isEmpty {
            tableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView?.scrollRowToVisible(0)
        }
    }

    // MARK: - 表格

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("clipCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: nil) as? ClipCell)
            ?? ClipCell(width: Self.panelSize.width)
        cell.identifier = identifier
        let item = items[row]
        cell.previewField.stringValue = item.preview
        cell.previewField.textColor = .labelColor
        cell.timeField.stringValue = item.relativeTime
        return cell
    }

    @objc private func doubleClickedRow() {
        let row = tableView?.clickedRow ?? -1
        guard items.indices.contains(row) else { return }
        paste(items[row])
    }

    // MARK: - 键盘

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(-1)
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            pasteSelected()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            hide(restoreFocus: true)
            return true
        case #selector(NSResponder.insertTab(_:)):
            return true
        default:
            return false
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        refilter()
    }

    private func moveSelection(_ offset: Int) {
        guard !items.isEmpty, let table = tableView else { return }
        let current = table.selectedRow
        let next = min(max(current + offset, 0), items.count - 1)
        table.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        table.scrollRowToVisible(next)
    }

    private func pasteSelected() {
        guard let table = tableView, items.indices.contains(table.selectedRow) else { return }
        paste(items[table.selectedRow])
    }

    // MARK: - 粘贴

    private func paste(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        // 自己写进去的内容重复入栈会自动提到最前
        ClipboardStore.shared.record(item.text)

        isPasting = true
        let target = previousApp
        hide(restoreFocus: false)
        if let target { DockApps.activate(target) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            Synth.combo(13, .maskCommand)  // ⌘V
            self.isPasting = false
        }
    }
}
