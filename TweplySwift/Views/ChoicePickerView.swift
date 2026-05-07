import SwiftUI

// MARK: - PickerState

/// Reference-type state holder so that the NSEvent key monitor closure can
/// safely mutate @Published properties and trigger SwiftUI re-renders.
@MainActor
final class PickerState: ObservableObject {
    @Published var values: [String]
    @Published var highlighted: [Int]

    let descriptors: [FieldDescriptor]
    var onComplete: (([String]?) -> Void)?

    private var monitor: Any?

    init(descriptors: [FieldDescriptor]) {
        self.descriptors = descriptors
        var vals  = [String]()
        var highs = [Int]()
        for desc in descriptors {
            switch desc.kind {
            case .select(let opts):
                vals.append(opts.first ?? "")
                highs.append(0)
            case .input, .textArea:
                vals.append("")
                highs.append(0)
            case .number(_, let min, _):
                vals.append(min.map { String(Int($0)) } ?? "0")
                highs.append(0)
            case .toggle(_, _, let off):
                vals.append(off)
                highs.append(0)
            }
        }
        values      = vals
        highlighted = highs
    }

    var allFilled: Bool {
        for (i, desc) in descriptors.enumerated() {
            switch desc.kind {
            case .input:
                if values[i].isEmpty { return false }
            case .number(_, let min, let max):
                guard let n = Double(values[i]) else { return false }
                if let lo = min, n < lo { return false }
                if let hi = max, n > hi { return false }
            default: break
            }
        }
        return true
    }

    // MARK: Key monitor

    func installKeyMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    func removeKeyMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        // Let text views handle their own keys (input / textArea fields)
        if NSApp.keyWindow?.firstResponder is NSTextView { return event }

        switch Int(event.keyCode) {
        case 53: // Escape — cancel
            onComplete?(nil)
            return nil

        case 36, 76: // Return / numpad Enter — confirm if all fields are filled
            if allFilled { onComplete?(values) }
            return nil

        default: break
        }

        // Only handle remaining keys if they are unmodified
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard flags.isEmpty else { return event }

        guard let (selectIdx, opts) = firstSelectPair() else { return event }

        switch Int(event.keyCode) {
        case 125: // ↓ — navigate, do not auto-complete
            highlighted[selectIdx] = min(highlighted[selectIdx] + 1, opts.count - 1)
            values[selectIdx]      = opts[highlighted[selectIdx]]
            return nil
        case 126: // ↑ — navigate, do not auto-complete
            highlighted[selectIdx] = max(highlighted[selectIdx] - 1, 0)
            values[selectIdx]      = opts[highlighted[selectIdx]]
            return nil
        default:
            if let chars = event.characters, let n = Int(chars), n >= 1, n <= opts.count {
                highlighted[selectIdx] = n - 1
                values[selectIdx]      = opts[n - 1]
                if allFilled { onComplete?(values) }
                return nil
            }
        }
        return event
    }

    private func firstSelectPair() -> (Int, [String])? {
        for (i, desc) in descriptors.enumerated() {
            if case .select(let opts) = desc.kind { return (i, opts) }
        }
        return nil
    }
}

// MARK: - ChoicePickerView

struct ChoicePickerView: View {
    @StateObject private var state: PickerState
    @FocusState  private var focusedIndex: Int?

    init(descriptors: [FieldDescriptor], onComplete: @escaping ([String]?) -> Void) {
        let s = PickerState(descriptors: descriptors)
        s.onComplete = onComplete
        _state = StateObject(wrappedValue: s)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(state.descriptors.enumerated()), id: \.offset) { i, desc in
                        fieldView(for: desc, at: i)
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 440)
        }
        .frame(width: 420)
        .onAppear {
            focusedIndex = state.descriptors.firstIndex {
                if case .input = $0.kind { return true }
                if case .number = $0.kind { return true }
                return false
            }
            state.installKeyMonitor()
        }
        .onDisappear { state.removeKeyMonitor() }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 2) {
            Text("Fill in the values")
                .font(.headline)
            Text("↑↓ or 1–9 to pick · ↩ to confirm · esc to cancel")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
    }

    // MARK: Field dispatch

    @ViewBuilder
    private func fieldView(for descriptor: FieldDescriptor, at index: Int) -> some View {
        switch descriptor.kind {
        case .select(let options):   selectField(options: options, at: index)
        case .input(let label):      inputField(label: label, at: index)
        case .textArea(let label):   textAreaField(label: label, at: index)
        case .number(let l, let lo, let hi): numberField(label: l, min: lo, max: hi, at: index)
        case .toggle(let l, let on, let off): toggleField(label: l, on: on, off: off, at: index)
        }
    }

    // MARK: Select

    private func selectField(options: [String], at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Choose one")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: 2) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    let isOn = state.highlighted[index] == i
                    Button {
                        state.highlighted[index] = i
                        state.values[index]      = option
                        if state.allFilled { state.onComplete?(state.values) }
                    } label: {
                        HStack(spacing: 8) {
                            Text("\(i + 1)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(isOn ? Color.white.opacity(0.7) : .secondary)
                                .frame(width: 16, alignment: .center)
                            Text(option)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isOn ? Color.accentColor : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                }
            }
        }
    }

    // MARK: Input

    private func inputField(label: String, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: $state.values[index])
                .textFieldStyle(.roundedBorder)
                .focused($focusedIndex, equals: index)
                .onSubmit { advance(from: index) }
        }
    }

    // MARK: TextArea

    private func textAreaField(label: String, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $state.values[index])
                .frame(minHeight: 64, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
    }

    // MARK: Number

    private func numberField(label: String, min: Double?, max: Double?, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rangeCaption(label, min, max)).font(.caption).foregroundStyle(.secondary)
            TextField("Number", text: $state.values[index])
                .textFieldStyle(.roundedBorder)
                .focused($focusedIndex, equals: index)
                .onSubmit { advance(from: index) }
        }
    }

    private func rangeCaption(_ label: String, _ min: Double?, _ max: Double?) -> String {
        switch (min, max) {
        case (.some(let lo), .some(let hi)): return "\(label) (\(Int(lo))–\(Int(hi)))"
        case (.some(let lo), nil):           return "\(label) (≥ \(Int(lo)))"
        case (nil, .some(let hi)):           return "\(label) (≤ \(Int(hi)))"
        default:                             return label
        }
    }

    // MARK: Toggle

    private func toggleField(label: String, on: String, off: String, at index: Int) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { state.values[index] == on },
                set: { state.values[index] = $0 ? on : off }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    // MARK: Focus advance

    private func advance(from index: Int) {
        for i in (index + 1)..<state.descriptors.count {
            switch state.descriptors[i].kind {
            case .input, .number:
                focusedIndex = i
                return
            default: continue
            }
        }
        if state.allFilled { state.onComplete?(state.values) }
    }
}
