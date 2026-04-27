import SwiftUI

struct TemplateEditorView: View {
    @State private var draft: Template
    let onSave:   (Template) -> Void
    let onCancel: () -> Void

    @State private var segments: [Segment] = []
    @State private var showRaw        = false
    @State private var rawText        = ""
    @State private var showIconPicker = false

    init(template: Template, onSave: @escaping (Template) -> Void, onCancel: @escaping () -> Void) {
        _draft        = State(initialValue: template)
        self.onSave   = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            nameRow
            Divider()
            iconRow
            Divider()
            chipArea
            Divider()
            paletteArea
            Divider()
            previewRow
            Divider()
            toolbarRow
        }
        // Resizable — no fixed height
        .frame(minWidth: 520, idealWidth: 620, maxWidth: .infinity,
               minHeight: 480, idealHeight: 580, maxHeight: .infinity)
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selectedIcon: $draft.icon)
        }
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

    // MARK: - Icon

    private var iconRow: some View {
        HStack(spacing: 10) {
            Text("Icon:")
                .frame(width: 50, alignment: .trailing)

            Button { showIconPicker = true } label: {
                Group {
                    if let icon = draft.icon, !icon.isEmpty {
                        Image(systemName: icon).font(.system(size: 15))
                    } else {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 28, height: 28)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            if let icon = draft.icon, !icon.isEmpty {
                Text(icon).font(.caption).foregroundStyle(.secondary)
                Button("Remove") { draft.icon = nil }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Chip Area

    @ViewBuilder
    private var chipArea: some View {
        if showRaw {
            TextEditor(text: $rawText)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(minHeight: 100, maxHeight: .infinity)
                .onChange(of: rawText) { _, v in
                    segments       = TemplateParser.parse(v)
                    draft.template = v
                }
        } else {
            Group {
                if segments.isEmpty {
                    Text("Add chips from the palette below")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(segments.enumerated()), id: \.element.id) { idx, _ in
                            ChipRowView(
                                segment:  $segments[idx],
                                onDelete: { removeChip(at: idx) }
                            )
                            .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onMove { from, to in
                            segments.move(fromOffsets: from, toOffset: to)
                            syncFromSegments()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(minHeight: 100, maxHeight: .infinity)
        }
    }

    private func removeChip(at idx: Int) { segments.remove(at: idx); syncFromSegments() }

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
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
                .padding(.top, 3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if cat == .text {
                        Button("Text") { appendChip(Segment(type: .text, value: "text")) }
                            .buttonStyle(.bordered).font(.caption)
                    } else {
                        ForEach(cat.types, id: \.self) { type in
                            Button(type.rawValue) { appendChip(defaultSegment(for: type)) }
                                .buttonStyle(.bordered).font(.caption).tint(cat.color)
                        }
                    }
                }
            }
        }
    }

    private func appendChip(_ seg: Segment) { segments.append(seg); syncFromSegments() }

    private func defaultSegment(for type: SegmentType) -> Segment {
        switch type {
        case .currentDate:     return Segment(type: .currentDate,     args: ["YYYY-MM-DD"])
        case .currentTime:     return Segment(type: .currentTime,     args: ["HH:mm:ss"])
        case .currentDateTime: return Segment(type: .currentDateTime, args: ["YYYY-MM-DDTHH:mm:ss"])
        case .choice:          return Segment(type: .choice,          args: ["option1", "option2"])
        case .input:           return Segment(type: .input,           args: ["Label"])
        case .counter:         return Segment(type: .counter,         args: ["id"])
        case .env:             return Segment(type: .env,             args: ["VAR_NAME"])
        case .nanoId:          return Segment(type: .nanoId,          args: ["10"])
        case .random:          return Segment(type: .random,          args: ["100"])
        case .randomHex:       return Segment(type: .randomHex,       args: ["8"])
        default:               return Segment(type: type)
        }
    }

    // MARK: - Preview

    private var previewRow: some View {
        HStack {
            Text("Preview:").font(.caption).foregroundStyle(.secondary)
            Text((try? TemplateResolver.resolveAll(segments)) ?? draft.template)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1).truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: - Toolbar

    private var toolbarRow: some View {
        HStack {
            Toggle("Raw", isOn: $showRaw)
                .toggleStyle(.button)
                .onChange(of: showRaw) { _, raw in
                    if raw { rawText  = TemplateParser.stringify(segments) }
                    else   { segments = TemplateParser.parse(rawText); draft.template = rawText }
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

private struct DateFormatOption {
    let label: String
    let format: String
}

struct ChipRowView: View {
    @Binding var segment: Segment
    let onDelete: () -> Void

    @State private var showCustomFormat = false

    private var isDateFormatType: Bool {
        [SegmentType.currentDate, .currentTime, .currentDateTime].contains(segment.type)
    }

    private static func dateFormats(for type: SegmentType) -> [DateFormatOption] {
        switch type {
        case .currentDate:
            return [
                DateFormatOption(label: "ISO 8601",  format: "YYYY-MM-DD"),
                DateFormatOption(label: "US",         format: "MM/DD/YYYY"),
                DateFormatOption(label: "European",   format: "DD.MM.YYYY"),
                DateFormatOption(label: "Short",      format: "DD MMM YYYY"),
                DateFormatOption(label: "Long",       format: "MMMM DD, YYYY"),
                DateFormatOption(label: "Compact",    format: "YYYYMMDD"),
            ]
        case .currentTime:
            return [
                DateFormatOption(label: "24h full",   format: "HH:mm:ss"),
                DateFormatOption(label: "24h short",  format: "HH:mm"),
            ]
        case .currentDateTime:
            return [
                DateFormatOption(label: "ISO 8601",   format: "YYYY-MM-DDTHH:mm:ss"),
                DateFormatOption(label: "Full",       format: "YYYY-MM-DD HH:mm:ss"),
                DateFormatOption(label: "European",   format: "DD.MM.YYYY HH:mm"),
                DateFormatOption(label: "US",         format: "MM/DD/YYYY HH:mm"),
            ]
        default: return []
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Type badge
            Text(segment.type.rawValue)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(segment.type.color.opacity(0.2))
                .foregroundStyle(segment.type.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Value / args editor
            if segment.type == .text {
                TextField("Text", text: Binding(
                    get: { segment.value ?? "" },
                    set: { segment.value = $0 }
                ))
                .textFieldStyle(.roundedBorder).font(.caption)
            } else if isDateFormatType {
                dateFormatEditor
            } else if !segment.args.isEmpty {
                TextField("args", text: Binding(
                    get: { segment.args.joined(separator: ",") },
                    set: { segment.args = $0.components(separatedBy: ",") }
                ))
                .textFieldStyle(.roundedBorder).font(.caption)
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
                .fixedSize().frame(maxWidth: 80)
            }

            Spacer()

            Button { onDelete() } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var dateFormatEditor: some View {
        let formats       = Self.dateFormats(for: segment.type)
        let currentFormat = segment.args.first ?? ""
        let isCustom      = !formats.contains(where: { $0.format == currentFormat }) && !currentFormat.isEmpty

        Menu {
            ForEach(Array(formats.enumerated()), id: \.offset) { _, fmt in
                Button {
                    segment.args     = [fmt.format]
                    showCustomFormat = false
                } label: {
                    Text(fmt.label)
                    Text(fmt.format).foregroundStyle(.secondary)
                }
            }
            Divider()
            Button("Custom…") {
                showCustomFormat = true
                if (segment.args.first ?? "").isEmpty {
                    segment.args = [formats.first?.format ?? ""]
                }
            }
        } label: {
            Text(currentFormat.isEmpty ? "format" : currentFormat)
                .font(.caption)
                .foregroundStyle(currentFormat.isEmpty ? .tertiary : .primary)
        }
        .fixedSize()

        if showCustomFormat || isCustom {
            TextField("e.g. YYYY-MM-DD", text: Binding(
                get: { segment.args.first ?? "" },
                set: { segment.args = [$0] }
            ))
            .textFieldStyle(.roundedBorder).font(.caption)
            .frame(maxWidth: 130)
        }
    }
}
