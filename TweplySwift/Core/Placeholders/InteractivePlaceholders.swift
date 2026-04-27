import Foundation

func registerInteractivePlaceholders() {
    let r = PlaceholderRegistry.shared

    r.registerInteractive(.choice) { s in
        FieldDescriptor(kind: .select(options: s.args.isEmpty ? ["option1"] : s.args))
    }

    r.registerInteractive(.input) { s in
        FieldDescriptor(kind: .input(label: s.args.first ?? "Value"))
    }
}
