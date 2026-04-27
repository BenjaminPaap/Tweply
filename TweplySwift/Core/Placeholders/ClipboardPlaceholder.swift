import AppKit

func registerClipboardPlaceholder() {
    PlaceholderRegistry.shared.register(.clipboard) { _ in
        NSPasteboard.general.string(forType: .string) ?? ""
    }
}
