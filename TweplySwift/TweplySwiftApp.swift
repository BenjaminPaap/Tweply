import SwiftUI

@main
struct TweplySwiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No persistent windows — everything lives in the status bar menu.
        // A Settings scene is required for macOS apps without a main window.
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

        // Build the status bar menu
        let controller = StatusBarController()
        controller.setup()
        statusBar = controller
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
