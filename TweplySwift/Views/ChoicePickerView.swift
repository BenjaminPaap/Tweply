import SwiftUI

struct ChoicePickerView: View {
    let descriptors: [FieldDescriptor]
    let onComplete: ([String]?) -> Void

    @State private var values: [String]
    @FocusState private var focusedIndex: Int?

    init(descriptors: [FieldDescriptor], onComplete: @escaping ([String]?) -> Void) {
        self.descriptors = descriptors
        self.onComplete  = onComplete
        _values = State(initialValue: Array(repeating: "", count: descriptors.count))
    }

    private var allFilled: Bool { !values.contains(where: \.isEmpty) }

    var body: some View {
        VStack(spacing: 0) {
            Text("Fill in the values")
                .font(.headline)
                .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(descriptors.enumerated()), id: \.offset) { index, descriptor in
                        fieldView(for: descriptor, at: index)
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { onComplete(nil) }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Copy") { onComplete(values) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!allFilled)
                    .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 420)
        .onAppear { focusedIndex = 0 }
    }

    @ViewBuilder
    private func fieldView(for descriptor: FieldDescriptor, at index: Int) -> some View {
        switch descriptor.kind {
        case .select(let options):
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        values[index] = option
                        autoAdvance(from: index)
                    }
                    .buttonStyle(.bordered)
                    .background(
                        values[index] == option ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                Spacer()
            }

        case .input(let label):
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(label, text: $values[index])
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedIndex, equals: index)
                    .onSubmit { autoAdvance(from: index) }
            }
        }
    }

    private func autoAdvance(from index: Int) {
        if let next = values.enumerated().first(where: { $0.offset > index && $0.element.isEmpty })?.offset {
            focusedIndex = next
        } else if allFilled {
            onComplete(values)
        }
    }
}
