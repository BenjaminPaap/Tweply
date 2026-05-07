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
    var hkID = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                      EventParamType(typeEventHotKeyID), nil,
                      MemoryLayout<EventHotKeyID>.size, nil, &hkID)
    DispatchQueue.main.async {
        if hkID.id == 2 { mgr.onActivateAndPaste?() }
        else             { mgr.onActivate?() }
    }
    return noErr
}

// Registers global keyboard shortcuts using Carbon's RegisterEventHotKey,
// which works inside the App Sandbox without Accessibility permission.
final class HotKeyManager {
    static let shared = HotKeyManager()
    private init() {}

    var onActivate: (() -> Void)?
    /// Fired by the paste hotkey (Cmd+Shift+V). Copy to clipboard then simulate paste.
    var onActivateAndPaste: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var pasteHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func apply(settings: AppSettings) {
        unregister()
        installEventHandler()
        if settings.hotkeyEnabled {
            let hkID = EventHotKeyID(signature: fourCharCode("TWPL"), id: 1)
            RegisterEventHotKey(UInt32(settings.hotkeyKeyCode),
                                UInt32(settings.hotkeyModifiers),
                                hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
        }
        // Cmd+Shift+V (keyCode 9, modifiers 768) is always registered as the paste hotkey.
        let hkID2 = EventHotKeyID(signature: fourCharCode("TWPL"), id: 2)
        RegisterEventHotKey(9, 768, hkID2, GetApplicationEventTarget(), 0, &pasteHotKeyRef)
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1, &eventType, selfPtr, &eventHandlerRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef      { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = pasteHotKeyRef { UnregisterEventHotKey(ref); pasteHotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref);   eventHandlerRef = nil }
    }
}

private func fourCharCode(_ s: String) -> FourCharCode {
    s.utf8.prefix(4).reduce(0) { ($0 << 8) + FourCharCode($1) }
}
