import AppKit
import Foundation

extension Notification.Name {
    static let clipboardHistoryDidChange = Notification.Name("tweply.clipboardHistoryDidChange")
}

@MainActor
final class ClipboardManager {
    static let shared = ClipboardManager()
    private init() {}

    private(set) var items: [ClipboardHistoryItem] = []
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var skipNextChange = false
    private var lastActiveApp: (bundleID: String, name: String)? = nil

    func start() {
        items = DataStore.shared.loadClipboardHistory()
        lastChangeCount = NSPasteboard.general.changeCount

        // Track which app was last active so we can attribute clipboard writes
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                  let bid = app.bundleIdentifier,
                  let name = app.localizedName
            else { return }
            Task { @MainActor [weak self] in
                self?.lastActiveApp = (bid, name)
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call before writing to the clipboard so the write is not recorded in history.
    func markOwnWrite() { skipNextChange = true }

    private func poll() {
        let pb    = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if skipNextChange { skipNextChange = false; return }

        guard let str = pb.string(forType: .string),
              !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard items.first?.content != str else { return }

        let new = ClipboardHistoryItem(
            content: str,
            sourceAppBundleID: lastActiveApp?.bundleID,
            sourceAppName: lastActiveApp?.name
        )
        items.insert(new, at: 0)

        let maxItems = DataStore.shared.loadSettings().maxClipboardHistoryItems
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }

        DataStore.shared.saveClipboardHistory(items)
        NotificationCenter.default.post(name: .clipboardHistoryDidChange, object: nil)
    }

    func copyItem(_ item: ClipboardHistoryItem) {
        markOwnWrite()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)

        // Move to front while keeping the original timestamp
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        DataStore.shared.saveClipboardHistory(items)
        NotificationCenter.default.post(name: .clipboardHistoryDidChange, object: nil)
    }

    func removeItem(_ item: ClipboardHistoryItem) {
        items.removeAll { $0.id == item.id }
        DataStore.shared.saveClipboardHistory(items)
        NotificationCenter.default.post(name: .clipboardHistoryDidChange, object: nil)
    }

    func clearAll() {
        items.removeAll()
        DataStore.shared.saveClipboardHistory(items)
        NotificationCenter.default.post(name: .clipboardHistoryDidChange, object: nil)
    }
}
