import AppKit
import SwiftUI

// MARK: - SearchMenuItemView

/// Custom NSView embedding an NSSearchField at the top of the clipboard history section.
/// Uses NSSearchFieldDelegate (not target/action) for reliable per-keystroke filtering inside
/// an NSMenu tracking loop, and explicitly sets insertionPointColor so the cursor is visible
/// even though the NSMenuWindow is not a standard key window.
final class SearchMenuItemView: NSView {
    let field: NSSearchField
    var onChange: ((String) -> Void)?

    override init(frame: NSRect) {
        field = NSSearchField()
        super.init(frame: frame)
        autoresizingMask = [.width]

        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholderString = "Search clipboard history…"
        field.controlSize = .regular
        field.delegate = self
        addSubview(field)

        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in self?.activateField() }
    }

    // Also handle direct clicks so the cursor appears if the user clicks the field.
    override func mouseDown(with event: NSEvent) {
        activateField()
        field.mouseDown(with: event)
    }

    private func activateField() {
        guard let window else { return }
        window.makeFirstResponder(field)
        // NSMenuWindow is not a proper key window, so the cursor would be invisible
        // without an explicit color — .labelColor adapts to light/dark mode.
        (field.currentEditor() as? NSTextView)?.insertionPointColor = .labelColor
    }
}

extension SearchMenuItemView: NSSearchFieldDelegate {
    // Called on every keystroke — more reliable than target/action in NSMenu context.
    func controlTextDidChange(_ obj: Notification) {
        onChange?(field.stringValue)
    }
}

// MARK: - StatusBarController

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var activeCoordinator: ChoicePickerCoordinator?
    private var settingsWindow: NSWindow?
    private var settingsWindowDelegate: WindowCloseDelegate?

    // Menu management
    private let menu = NSMenu()
    private var menuDelegate: StatusBarMenuDelegate?
    private var isMenuOpen = false
    private var historyScrollView: ClipboardScrollMenuItemView?

    func openMenu() {
        rebuildMenu()
        let position = NSEvent.mouseLocation
        // Convert to screen coordinates and pop the menu at the cursor
        menu.popUp(positioning: nil,
                   at: NSPoint(x: position.x, y: position.y),
                   in: nil)
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image   = makeStatusIcon()
            button.toolTip = "Tweply"
        }

        let delegate = StatusBarMenuDelegate()
        delegate.onWillOpen = { [weak self] in self?.menuWillOpenHandler() }
        delegate.onDidClose = { [weak self] in self?.isMenuOpen = false }
        menuDelegate = delegate
        menu.delegate = delegate
        statusItem.menu = menu

        rebuildMenu()

        NotificationCenter.default.addObserver(
            forName: .templatesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isMenuOpen else { return }
                self.rebuildMenu()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .clipboardHistoryDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isMenuOpen else { return }
                self.rebuildMenu()
            }
        }
    }

    private func menuWillOpenHandler() {
        isMenuOpen = true
        rebuildMenu()
    }

    // MARK: - Menu Building

    func rebuildMenu() {
        menu.removeAllItems()
        historyScrollView = nil

        let settings  = DataStore.shared.loadSettings()
        let templates = DataStore.shared.loadTemplates()

        if settings.templatesAboveClipboard {
            addTemplatesSection(templates)
            if settings.clipboardHistoryEnabled {
                menu.addItem(.separator())
                addClipboardHistorySection(settings: settings)
                menu.addItem(.separator())
            } else if !templates.isEmpty {
                menu.addItem(.separator())
            }
        } else {
            if settings.clipboardHistoryEnabled {
                addClipboardHistorySection(settings: settings)
                menu.addItem(.separator())
            }
            addTemplatesSection(templates)
            if !templates.isEmpty { menu.addItem(.separator()) }
        }

        let settingsItem = NSMenuItem(
            title:         "Settings…",
            action:        #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title:         "Quit Tweply",
            action:        #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }

    private func addTemplatesSection(_ templates: [Template]) {
        for template in templates {
            if template.isSeparator {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(
                title:         template.name,
                action:        #selector(activateItem(_:)),
                keyEquivalent: ""
            )
            item.target            = self
            item.representedObject = template
            if let iconName = template.icon,
               !iconName.isEmpty,
               let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
                item.image = img.withSymbolConfiguration(
                    NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                )
            }
            menu.addItem(item)
        }
    }

    // MARK: - Clipboard History Section

    private func addClipboardHistorySection(settings: AppSettings) {
        let searchItem = NSMenuItem()
        let sv = SearchMenuItemView(frame: NSRect(x: 0, y: 0, width: 300, height: 40))
        sv.onChange = { [weak self] query in self?.filterHistory(query: query) }
        searchItem.view = sv
        menu.addItem(searchItem)

        let items = ClipboardManager.shared.items
        if items.isEmpty {
            let empty = NSMenuItem(title: "No clipboard history", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let rowH    = CGFloat(28)
            let visible = min(items.count, settings.menuClipboardRows)
            let scrollH = rowH * CGFloat(visible)

            let scrollView = ClipboardScrollMenuItemView(
                frame:    NSRect(x: 0, y: 0, width: 300, height: scrollH),
                items:    items,
                settings: settings,
                rowHeight: rowH,
                iconCache: &iconCache,
                onSelect: { [weak self] item in
                    guard let self else { return }
                    ClipboardManager.shared.copyItem(item)
                    self.menu.cancelTracking()
                    self.flashTooltip("Copied!")
                }
            )
            let scrollMenuItem = NSMenuItem()
            scrollMenuItem.view = scrollView
            menu.addItem(scrollMenuItem)
            historyScrollView = scrollView
        }

        let clearItem = NSMenuItem(
            title:         "Clear History",
            action:        #selector(clearHistory),
            keyEquivalent: ""
        )
        clearItem.target    = self
        clearItem.isEnabled = !items.isEmpty
        menu.addItem(clearItem)
    }

    // MARK: - App Icon Lookup

    private var iconCache: [String: NSImage] = [:]

    private func appIcon(forBundleID bundleID: String) -> NSImage? {
        if let cached = iconCache[bundleID] { return cached }
        guard let url  = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let full  = NSWorkspace.shared.icon(forFile: url.path)
        let small = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            full.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
            return true
        }
        iconCache[bundleID] = small
        return small
    }

    // MARK: - Tooltip

    private func buildTooltip(_ item: ClipboardHistoryItem) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium
        var parts: [String] = []
        if let name = item.sourceAppName { parts.append(name) }
        parts.append(df.string(from: item.timestamp))
        return parts.joined(separator: " · ")
    }

    // MARK: - Filtering

    private func filterHistory(query: String) {
        historyScrollView?.filter(query: query)
    }

    // MARK: - Menu Actions

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText     = "Clear Clipboard History?"
        alert.informativeText = "All entries will be permanently deleted. This cannot be undone."
        alert.alertStyle      = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        ClipboardManager.shared.clearAll()
    }

    @objc private func activateItem(_ sender: NSMenuItem) {
        guard let template = sender.representedObject as? Template else { return }
        Task { @MainActor in await activate(template) }
    }

    private func activate(_ template: Template) async {
        let segments = TemplateParser.parse(template.template)
        var userValues: [String] = []

        if TemplateResolver.requiresInteraction(segments) {
            let descriptors = TemplateResolver.interactiveDescriptors(segments)
            guard let values = await presentChoicePicker(descriptors: descriptors) else { return }
            userValues = values
        }

        do {
            let result = try TemplateResolver.resolveAll(segments, userValues: userValues)
            ClipboardManager.shared.markOwnWrite()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
            flashTooltip("Copied!")
        } catch {
            flashTooltip("Error")
        }
    }

    private func flashTooltip(_ message: String) {
        statusItem.button?.toolTip = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.statusItem.button?.toolTip = "Tweply"
        }
    }

    // MARK: - Settings

    @objc private func openSettings() {
        if let win = settingsWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hc  = NSHostingController(rootView: SettingsView())
        let win = NSWindow(contentViewController: hc)
        win.title           = "Settings"
        win.styleMask       = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.minSize         = NSSize(width: 600, height: 400)
        win.setContentSize(NSSize(width: 640, height: 480))
        win.center()
        win.isReleasedWhenClosed = false

        let delegate = WindowCloseDelegate { [weak self] in self?.settingsWindow = nil }
        win.delegate = delegate
        settingsWindowDelegate = delegate
        settingsWindow = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Choice Picker

    private func presentChoicePicker(descriptors: [FieldDescriptor]) async -> [String]? {
        return await withCheckedContinuation { continuation in
            let coordinator = ChoicePickerCoordinator(continuation: continuation)
            self.activeCoordinator = coordinator

            let view  = ChoicePickerView(descriptors: descriptors) { [weak coordinator] values in
                coordinator?.complete(values)
            }
            let hc    = NSHostingController(rootView: view)
            let panel = NSPanel(contentViewController: hc)
            panel.title     = ""
            panel.styleMask = [.titled, .closable]
            let panelSize = hc.view.fittingSize
            panel.setContentSize(panelSize)
            panel.setFrameOrigin(nearCursor: panelSize)
            panel.level    = .floating
            panel.isReleasedWhenClosed = false
            panel.delegate = coordinator
            coordinator.panel = panel

            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Status Icon

    private func makeStatusIcon() -> NSImage {
        let size  = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let attrs: [NSAttributedString.Key: Any] = [
                .font:            NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]
            let str = NSAttributedString(string: "T", attributes: attrs)
            let sz  = str.size()
            str.draw(at: NSPoint(x: (rect.width - sz.width) / 2,
                                 y: (rect.height - sz.height) / 2))
            return true
        }
        image.isTemplate = true
        return image
    }
}

// MARK: - StatusBarMenuDelegate

final class StatusBarMenuDelegate: NSObject, NSMenuDelegate {
    var onWillOpen: (() -> Void)?
    var onDidClose: (() -> Void)?

    func menuWillOpen(_ menu: NSMenu) { onWillOpen?() }
    func menuDidClose(_ menu: NSMenu) { onDidClose?() }
}

// MARK: - ChoicePickerCoordinator

final class ChoicePickerCoordinator: NSObject, NSWindowDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<[String]?, Never>
    private var resolved = false
    weak var panel: NSPanel?

    init(continuation: CheckedContinuation<[String]?, Never>) {
        self.continuation = continuation
    }

    func complete(_ values: [String]?) {
        guard !resolved else { return }
        resolved = true
        panel?.close()
        continuation.resume(returning: values)
    }

    func windowWillClose(_ notification: Notification) { complete(nil) }
}

// MARK: - WindowCloseDelegate  (kept for potential future use)

final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}

// MARK: - ClipboardRowView

final class ClipboardRowView: NSView {
    let item: ClipboardHistoryItem
    private let label: NSTextField
    private let iconView: NSImageView
    private let onSelect: () -> Void

    init(frame: NSRect, item: ClipboardHistoryItem, settings: AppSettings,
         icon: NSImage?, onSelect: @escaping () -> Void) {
        self.item     = item
        self.onSelect = onSelect

        label    = NSTextField(labelWithString: "")
        iconView = NSImageView()
        super.init(frame: frame)
        wantsLayer = true

        var display: String
        if item.isLikelyPassword && settings.obfuscatePasswords {
            display = PasswordDetector.obfuscate(item.content)
        } else {
            display = item.content
        }
        display = display
            .replacingOccurrences(of: "\n", with: "↵")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: "⇥")
        if display.count > 60 { display = String(display.prefix(60)) + "…" }

        label.stringValue       = display
        label.lineBreakMode     = .byTruncatingTail
        label.font              = .menuFont(ofSize: NSFont.systemFontSize(for: .regular))
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        iconView.image          = icon
        iconView.imageScaling   = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) { setHighlighted(true) }
    override func mouseExited(with event: NSEvent)  { setHighlighted(false) }
    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if bounds.contains(p) { onSelect() }
    }

    private func setHighlighted(_ on: Bool) {
        layer?.backgroundColor = on ? NSColor.selectedMenuItemColor.cgColor : nil
        label.textColor = on ? .selectedMenuItemTextColor : .labelColor
    }
}

// MARK: - ClipboardScrollMenuItemView

final class ClipboardScrollMenuItemView: NSView {
    private var rowViews: [ClipboardRowView] = []
    private let scrollView   = NSScrollView()
    private let documentView = NSView()
    private let rowHeight: CGFloat
    private let maxHeight: CGFloat  // capped height passed in from outside; never shrinks below this

    init(frame: NSRect, items: [ClipboardHistoryItem], settings: AppSettings,
         rowHeight: CGFloat, iconCache: inout [String: NSImage],
         onSelect: @escaping (ClipboardHistoryItem) -> Void) {
        self.rowHeight = rowHeight
        self.maxHeight = frame.height
        super.init(frame: frame)
        autoresizingMask = [.width]

        scrollView.frame                = bounds
        scrollView.autoresizingMask     = [.width, .height]
        scrollView.hasVerticalScroller  = true
        scrollView.autohidesScrollers   = true
        scrollView.drawsBackground      = false
        scrollView.scrollerStyle        = .overlay
        addSubview(scrollView)

        let totalH = CGFloat(items.count) * rowHeight
        documentView.frame = NSRect(x: 0, y: 0, width: frame.width, height: totalH)
        documentView.autoresizingMask = [.width]
        scrollView.documentView = documentView

        for (idx, item) in items.enumerated() {
            let icon = resolvedIcon(for: item, settings: settings, cache: &iconCache)
            let y    = totalH - rowHeight * CGFloat(idx + 1)
            let row  = ClipboardRowView(
                frame:    NSRect(x: 0, y: y, width: frame.width, height: rowHeight),
                item:     item,
                settings: settings,
                icon:     icon,
                onSelect: { onSelect(item) }
            )
            row.autoresizingMask = [.width]
            documentView.addSubview(row)
            rowViews.append(row)
        }

        // Scroll to top
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: totalH - frame.height))
    }

    required init?(coder: NSCoder) { fatalError() }

    func filter(query: String) {
        var visibleY = CGFloat(0)
        for row in rowViews.reversed() {
            let visible = query.isEmpty || row.item.content.localizedCaseInsensitiveContains(query)
            row.isHidden = !visible
            if visible {
                row.frame.origin.y = visibleY
                visibleY += rowHeight
            }
        }
        documentView.frame.size.height = max(visibleY, 1)
        // Always clamp against maxHeight (the original height) so clearing the
        // search fully restores the list — frame.height shrinks when filtering,
        // so using it here would permanently cap the restored size.
        let frameH = min(visibleY, maxHeight)
        frame.size.height = frameH
        scrollView.frame  = bounds
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: max(0, visibleY - frameH)))
    }

    private func resolvedIcon(for item: ClipboardHistoryItem, settings: AppSettings,
                              cache: inout [String: NSImage]) -> NSImage? {
        if item.isLikelyPassword && settings.obfuscatePasswords {
            return NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 11, weight: .regular))
        }
        guard let bid = item.sourceAppBundleID else { return nil }
        if let cached = cache[bid] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) else { return nil }
        let full  = NSWorkspace.shared.icon(forFile: url.path)
        let small = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            full.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
            return true
        }
        cache[bid] = small
        return small
    }
}

// MARK: - NSWindow convenience

private extension NSWindow {
    /// Positions the window near the current mouse cursor, clamped so it stays
    /// fully within the visible area of whichever screen the cursor is on.
    func setFrameOrigin(nearCursor size: NSSize) {
        let mouse  = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
                     ?? NSScreen.main
                     ?? NSScreen.screens[0]
        let vis    = screen.visibleFrame

        // Anchor top-left of the panel to the cursor, then clamp to visible frame.
        var origin = NSPoint(x: mouse.x, y: mouse.y - size.height)
        origin.x = max(vis.minX, min(origin.x, vis.maxX - size.width))
        origin.y = max(vis.minY, min(origin.y, vis.maxY - size.height))
        setFrameOrigin(origin)
    }
}
