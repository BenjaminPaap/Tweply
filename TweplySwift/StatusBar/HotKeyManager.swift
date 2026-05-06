import Carbon
import AppKit

// File-level C-compatible callback — closures that capture context cannot
// be used as C function pointers, so self is threaded through userData.
private func hotKeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let ptr = userData else { return OSStatus(eventNotHandledErr) }
    let mgr = Unmanaged<HotKeyManager>.fromOpaque(ptr).takeUnretainedValue()
    DispatchQueue.main.async { mgr.onActivate?() }
    return noErr
}

// Registers a global keyboard shortcut using Carbon's RegisterEventHotKey,
// which works inside the App Sandbox without Accessibility permission.
final class HotKeyManager {
    static let shared = HotKeyManager()
    private init() {}

    var onActivate: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func apply(settings: AppSettings) {
        unregister()
        guard settings.hotkeyEnabled else { return }
        register(keyCode: UInt32(settings.hotkeyKeyCode),
                 modifiers: UInt32(settings.hotkeyModifiers))
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        // InstallApplicationEventHandler is a C macro and not visible in Swift;
        // it expands to InstallEventHandler(GetApplicationEventTarget(), ...).
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1, &eventType, selfPtr, &eventHandlerRef
        )
        var hkID = EventHotKeyID(signature: fourCharCode("TWPL"), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hkID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef       { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref);    eventHandlerRef = nil }
    }
}

private func fourCharCode(_ s: String) -> FourCharCode {
    s.utf8.prefix(4).reduce(0) { ($0 << 8) + FourCharCode($1) }
}
