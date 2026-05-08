import SwiftUI

@main
struct TweplySwiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene must be declared so the app is valid on macOS,
        // but the actual window is managed by StatusBarController via NSHostingController.
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register all placeholder types
        registerDatePlaceholders()
        registerSystemPlaceholders()
        registerRandomPlaceholders()
        registerCounterPlaceholders()
        registerClipboardPlaceholder()
        registerInteractivePlaceholders()

        // Hide from Dock — this is a menu-bar-only app
        NSApp.setActivationPolicy(.accessory)

        // Start clipboard history monitoring
        ClipboardManager.shared.start()

        // Build the status bar menu
        let controller = StatusBarController()
        controller.setup()
        statusBar = controller

        // Check for updates if the interval has elapsed
        let settings = DataStore.shared.loadSettings()
        UpdateChecker.shared.checkIfDue(settings: settings)

        // Register global hotkeys
        HotKeyManager.shared.onActivate = { [weak controller] in
            controller?.openMenu()
        }
        HotKeyManager.shared.onActivateAndPaste = { [weak controller] in
            controller?.openMenuAndPaste()
        }
        HotKeyManager.shared.apply(settings: settings)

        NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { _ in
            let s = DataStore.shared.loadSettings()
            HotKeyManager.shared.apply(settings: s)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
