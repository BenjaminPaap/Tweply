import Foundation

func registerInteractivePlaceholders() {
    let r = PlaceholderRegistry.shared

    r.registerInteractive(.choice) { s in
        FieldDescriptor(kind: .select(options: s.args.isEmpty ? ["option1"] : s.args))
    }

    r.registerInteractive(.input) { s in
        FieldDescriptor(kind: .input(label: s.args.first ?? "Value"))
    }

    r.registerInteractive(.textArea) { s in
        FieldDescriptor(kind: .textArea(label: s.args.first ?? "Text"))
    }

    r.registerInteractive(.number) { s in
        let label = s.args.first ?? "Number"
        let min   = s.args.count > 1 ? Double(s.args[1]) : nil
        let max   = s.args.count > 2 ? Double(s.args[2]) : nil
        return FieldDescriptor(kind: .number(label: label, min: min, max: max))
    }

    r.registerInteractive(.toggle) { s in
        let label = s.args.first ?? "Toggle"
        let on    = s.args.count > 1 ? s.args[1] : "true"
        let off   = s.args.count > 2 ? s.args[2] : "false"
        return FieldDescriptor(kind: .toggle(label: label, on: on, off: off))
    }
}
