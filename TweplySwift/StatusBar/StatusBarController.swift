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

    // Paste mode: set to true when the paste hotkey fires; cleared after use or on menu close.
    private var pasteAfterCopy = false
    // The app that was frontmost when the paste hotkey fired — paste target.
    private var pasteTargetApp: NSRunningApplication?

    // References to clipboard NSMenuItems for search filtering.
    private var clipboardMenuItems: [NSMenuItem] = []

    @objc private func statusBarButtonClicked() {
        guard let button = statusItem.button else { return }
        // Non-paste open: clear any lingering paste state from a prior dismissed hotkey.
        pasteAfterCopy = false
        pasteTargetApp = nil
        rebuildMenu()
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height + 4),
                   in: button)
    }

    func openMenu() {
        // Non-paste open: clear any lingering paste state.
        pasteAfterCopy = false
        pasteTargetApp = nil
        rebuildMenu()
        let position = NSEvent.mouseLocation
        menu.popUp(positioning: nil,
                   at: NSPoint(x: position.x, y: position.y),
                   in: nil)
    }

    func openMenuAndPaste() {
        pasteTargetApp = NSWorkspace.shared.frontmostApplication
        pasteAfterCopy = true
        // Rebuild and show — do NOT call openMenu() as it would clear pasteAfterCopy.
        rebuildMenu()
        let position = NSEvent.mouseLocation
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

        // Route all menu opens through popUp() so the item action always fires
        // before menuDidClose — setting statusItem.menu causes the delegate to
        // fire menuDidClose BEFORE the action, which clears pasteAfterCopy too early.
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }

        let delegate = StatusBarMenuDelegate()
        delegate.onWillOpen = { [weak self] in self?.isMenuOpen = true }
        delegate.onDidClose = { [weak self] in
            self?.isMenuOpen = false
            // pasteAfterCopy/pasteTargetApp are NOT cleared here: menuDidClose fires
            // before the item action, so clearing here would wipe the paste state
            // before activateClipboardItem/activateItem can read it.
            // They are cleared in the action handlers and at the start of every
            // non-paste menu open (statusBarButtonClicked, openMenu).
        }
        menuDelegate = delegate
        menu.delegate = delegate

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

    // MARK: - Menu Building

    func rebuildMenu() {
        menu.removeAllItems()
        clipboardMenuItems = []

        // Show update badge at the very top when a newer version is available.
        if UpdateChecker.shared.updateAvailable, let latest = UpdateChecker.shared.latestVersion {
            let item = NSMenuItem(
                title:         "Update available: v\(latest) — Download",
                action:        #selector(openUpdatePage),
                keyEquivalent: ""
            )
            item.target = self
            item.image  = NSImage(systemSymbolName: "arrow.down.circle.fill",
                                  accessibilityDescription: nil)
            menu.addItem(item)
            menu.addItem(.separator())
        }

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
            for item in items.prefix(settings.menuClipboardRows) {
                let menuItem = makeClipboardMenuItem(item: item, settings: settings)
                menu.addItem(menuItem)
                clipboardMenuItems.append(menuItem)
            }
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

    private func makeClipboardMenuItem(item: ClipboardHistoryItem, settings: AppSettings) -> NSMenuItem {
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

        let menuItem = NSMenuItem(
            title:         display,
            action:        #selector(activateClipboardItem(_:)),
            keyEquivalent: ""
        )
        menuItem.target            = self
        menuItem.representedObject = item
        menuItem.toolTip           = buildTooltip(item)

        if let icon = resolvedClipboardIcon(for: item, settings: settings) {
            menuItem.image = icon
        }
        return menuItem
    }

    private func resolvedClipboardIcon(for item: ClipboardHistoryItem, settings: AppSettings) -> NSImage? {
        if item.isLikelyPassword && settings.obfuscatePasswords {
            return NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 11, weight: .regular))
        }
        guard let bid = item.sourceAppBundleID else { return nil }
        return appIcon(forBundleID: bid)
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
        for menuItem in clipboardMenuItems {
            guard let item = menuItem.representedObject as? ClipboardHistoryItem else { continue }
            menuItem.isHidden = !query.isEmpty && !item.content.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Paste Simulation

    private func simulatePaste(to target: NSRunningApplication?, extraDelay: Double = 0) {
        // AXIsProcessTrustedWithOptions with prompt:true is the only way to trigger
        // the Accessibility permission dialog. CGEvent silently fails without it.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): kCFBooleanTrue!] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            flashTooltip("Grant Accessibility access…")
            return
        }

        flashTooltip("Pasting…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 + extraDelay) {
            if #available(macOS 14.0, *) {
                target?.activate()
            } else {
                target?.activate(options: .activateIgnoringOtherApps)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let src = CGEventSource(stateID: .combinedSessionState)
                guard let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true),
                      let up   = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
                else { return }
                down.flags = .maskCommand
                up.flags   = .maskCommand
                down.post(tap: .cgAnnotatedSessionEventTap)
                up.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
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

    @objc private func activateClipboardItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardHistoryItem else { return }
        // Capture paste state synchronously while still inside the menu's run loop,
        // before onDidClose can clear the properties.
        let shouldPaste = pasteAfterCopy
        let target = pasteTargetApp
        pasteAfterCopy = false
        pasteTargetApp = nil
        ClipboardManager.shared.copyItem(item)
        flashTooltip("Copied!")
        if shouldPaste { simulatePaste(to: target) }
    }

    @objc private func activateItem(_ sender: NSMenuItem) {
        guard let template = sender.representedObject as? Template else { return }
        // Capture paste state synchronously here — the async Task below runs after
        // menu.popUp() returns and onDidClose fires, which would clear the properties.
        let shouldPaste = pasteAfterCopy
        let target = pasteTargetApp
        pasteAfterCopy = false
        pasteTargetApp = nil
        Task { @MainActor in await activate(template, shouldPaste: shouldPaste, target: target) }
    }

    private func activate(_ template: Template, shouldPaste: Bool = false, target: NSRunningApplication? = nil) async {
        let segments = TemplateParser.parse(template.template)
        var userValues: [String] = []
        var usedPicker = false

        if TemplateResolver.requiresInteraction(segments) {
            let descriptors = TemplateResolver.interactiveDescriptors(segments)
            guard let values = await presentChoicePicker(descriptors: descriptors) else { return }
            userValues = values
            usedPicker = true
        }

        do {
            let result = try TemplateResolver.resolveAll(segments, userValues: userValues)
            ClipboardManager.shared.markOwnWrite()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
            flashTooltip("Copied!")
            if shouldPaste { simulatePaste(to: target, extraDelay: usedPicker ? 0.35 : 0) }
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

    @objc private func openUpdatePage() {
        NSWorkspace.shared.open(URL(string: "https://tweply.paap.one")!)
    }

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
