import SwiftUI

struct TemplateEditorView: View {
    @State private var draft: Template
    let onSave:   (Template) -> Void
    let onCancel: () -> Void

    @State private var segments: [Segment] = []
    @State private var showRaw = false
    @State private var rawText = ""

    init(template: Template, onSave: @escaping (Template) -> Void, onCancel: @escaping () -> Void) {
        _draft    = State(initialValue: template)
        self.onSave   = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            nameRow
            Divider()
            chipArea
            Divider()
            paletteArea
            Divider()
            previewRow
            Divider()
            toolbarRow
        }
        .frame(width: 600, height: 520)
        .onAppear {
            segments = TemplateParser.parse(draft.template)
            rawText  = draft.template
        }
    }

    // MARK: - Name

    private var nameRow: some View {
        HStack {
            Text("Name:")
                .frame(width: 50, alignment: .trailing)
            TextField("Template name", text: $draft.name)
                .textFieldStyle(.roundedBorder)
        }
        .padding(12)
    }

    // MARK: - Chip Area

    @ViewBuilder
    private var chipArea: some View {
        if showRaw {
            TextEditor(text: $rawText)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(height: 120)
                .onChange(of: rawText) { _, v in
                    segments    = TemplateParser.parse(v)
                    draft.template = v
                }
        } else {
            ScrollView {
                if segments.isEmpty {
                    Text("Add chips from the palette below")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 4) {
                        ForEach(Array(segments.enumerated()), id: \.element.id) { idx, _ in
                            ChipRowView(
                                segment: $segments[idx],
                                onDelete: { removeChip(at: idx) },
                                onMoveUp:   idx > 0 ? { swapChip(idx, idx - 1) } : nil,
                                onMoveDown: idx < segments.count - 1 ? { swapChip(idx, idx + 1) } : nil
                            )
                        }
                    }
                    .padding(8)
                }
            }
            .frame(height: 120)
        }
    }

    private func removeChip(at idx: Int) {
        segments.remove(at: idx)
        syncFromSegments()
    }

    private func swapChip(_ a: Int, _ b: Int) {
        segments.swapAt(a, b)
        syncFromSegments()
    }

    private func appendChip(_ seg: Segment) {
        segments.append(seg)
        syncFromSegments()
    }

    private func syncFromSegments() {
        let str        = TemplateParser.stringify(segments)
        draft.template = str
        rawText        = str
    }

    // MARK: - Palette

    private var paletteArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(SegmentCategory.allCases, id: \.self) { cat in
                    paletteRow(for: cat)
                }
            }
            .padding(10)
        }
        .frame(height: 150)
    }

    private func paletteRow(for cat: SegmentCategory) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(cat.rawValue):")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
                .padding(.top, 3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if cat == .text {
                        Button("Text") {
                            appendChip(Segment(type: .text, value: "text"))
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    } else {
                        ForEach(cat.types, id: \.self) { type in
                            Button(type.rawValue) {
                                appendChip(defaultSegment(for: type))
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                            .tint(cat.color)
                        }
                    }
                }
            }
        }
    }

    private func defaultSegment(for type: SegmentType) -> Segment {
        switch type {
        case .choice:    return Segment(type: .choice,    args: ["option1", "option2"])
        case .input:     return Segment(type: .input,     args: ["Label"])
        case .counter:   return Segment(type: .counter,   args: ["id"])
        case .env:       return Segment(type: .env,       args: ["VAR_NAME"])
        case .nanoId:    return Segment(type: .nanoId,    args: ["10"])
        case .random:    return Segment(type: .random,    args: ["100"])
        case .randomHex: return Segment(type: .randomHex, args: ["8"])
        default:         return Segment(type: type)
        }
    }

    // MARK: - Preview

    private var previewRow: some View {
        HStack {
            Text("Preview:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(previewText)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var previewText: String {
        (try? TemplateResolver.resolveAll(segments)) ?? draft.template
    }

    // MARK: - Toolbar

    private var toolbarRow: some View {
        HStack {
            Toggle("Raw", isOn: $showRaw)
                .toggleStyle(.button)
                .onChange(of: showRaw) { _, raw in
                    if raw {
                        rawText  = TemplateParser.stringify(segments)
                    } else {
                        segments = TemplateParser.parse(rawText)
                        draft.template = rawText
                    }
                }
            Spacer()
            Button("Cancel", action: onCancel)
            Button("Save") {
                draft.template = showRaw ? rawText : TemplateParser.stringify(segments)
                onSave(draft)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.name.isEmpty)
        }
        .padding(12)
    }
}

// MARK: - ChipRowView

struct ChipRowView: View {
    @Binding var segment: Segment
    let onDelete:   () -> Void
    let onMoveUp:   (() -> Void)?
    let onMoveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            // Reorder buttons
            VStack(spacing: 0) {
                Button { onMoveUp?() } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9))
                }
                .disabled(onMoveUp == nil)
                .buttonStyle(.plain)
                .foregroundStyle(onMoveUp != nil ? .secondary : .quaternary)

                Button { onMoveDown?() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
                .disabled(onMoveDown == nil)
                .buttonStyle(.plain)
                .foregroundStyle(onMoveDown != nil ? .secondary : .quaternary)
            }

            // Type badge
            Text(segment.type.rawValue)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(segment.type.color.opacity(0.2))
                .foregroundStyle(segment.type.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Value / args editor
            if segment.type == .text {
                TextField("Text", text: Binding(
                    get:  { segment.value ?? "" },
                    set:  { segment.value = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            } else if !segment.args.isEmpty {
                TextField("args", text: Binding(
                    get: { segment.args.joined(separator: ",") },
                    set: { segment.args = $0.components(separatedBy: ",") }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(maxWidth: 160)
            }

            // Modifier picker
            if segment.type != .text {
                Menu {
                    Button("None") { segment.modifier = nil }
                    Divider()
                    ForEach(["upper", "lower", "slug", "alphanum"], id: \.self) { mod in
                        Button(mod) { segment.modifier = mod }
                    }
                } label: {
                    Text(segment.modifier ?? "modifier")
                        .font(.caption)
                        .foregroundStyle(segment.modifier != nil ? .primary : .tertiary)
                }
                .fixedSize()
                .frame(maxWidth: 80)
            }

            Spacer()

            Button { onDelete() } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
    }
}
