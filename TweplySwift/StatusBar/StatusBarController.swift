import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var activeCoordinator: ChoicePickerCoordinator?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image   = makeStatusIcon()
            button.toolTip = "Tweply"
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu      = NSMenu()
        let templates = DataStore.shared.loadTemplates()

        for template in templates {
            let item = NSMenuItem(
                title:          template.name,
                action:         #selector(activateItem(_:)),
                keyEquivalent:  ""
            )
            item.target             = self
            item.representedObject  = template
            menu.addItem(item)
        }

        if !templates.isEmpty { menu.addItem(.separator()) }

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

        statusItem.menu = menu
    }

    // MARK: - Menu actions

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
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView()
        let hc   = NSHostingController(rootView: view)
        let win  = NSWindow(contentViewController: hc)
        win.title      = "Tweply"
        win.styleMask  = [.titled, .closable, .resizable, .miniaturizable]
        win.setContentSize(NSSize(width: 640, height: 520))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = WindowCloseDelegate { [weak self] in
            self?.settingsWindow = nil
            self?.rebuildMenu()
        }

        settingsWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Choice Picker

    private func presentChoicePicker(descriptors: [FieldDescriptor]) async -> [String]? {
        return await withCheckedContinuation { continuation in
            let coordinator = ChoicePickerCoordinator(continuation: continuation)
            self.activeCoordinator = coordinator

            let view = ChoicePickerView(descriptors: descriptors) { [weak coordinator] values in
                coordinator?.complete(values)
            }
            let hc    = NSHostingController(rootView: view)
            let panel = NSPanel(contentViewController: hc)
            panel.title    = ""
            panel.styleMask = [.titled, .closable, .nonactivatingPanel]
            panel.setContentSize(hc.view.fittingSize)
            panel.center()
            panel.level    = .floating
            panel.isReleasedWhenClosed = false
            panel.delegate = coordinator
            coordinator.panel = panel

            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Icon

    private func makeStatusIcon() -> NSImage {
        let size   = NSSize(width: 18, height: 18)
        let image  = NSImage(size: size, flipped: false) { rect in
            let attrs: [NSAttributedString.Key: Any] = [
                .font:            NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]
            let str  = NSAttributedString(string: "T", attributes: attrs)
            let sz   = str.size()
            str.draw(at: NSPoint(x: (rect.width - sz.width) / 2,
                                 y: (rect.height - sz.height) / 2))
            return true
        }
        image.isTemplate = true
        return image
    }
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

    func windowWillClose(_ notification: Notification) {
        complete(nil)
    }
}

// MARK: - WindowCloseDelegate

final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
