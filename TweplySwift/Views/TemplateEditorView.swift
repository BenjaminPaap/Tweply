import SwiftUI

struct TemplateEditorView: View {
    @State private var draft: Template
    let onSave:   (Template) -> Void
    let onCancel: () -> Void

    @State private var segments: [Segment] = []
    @State private var showRaw        = false
    @State private var rawText        = ""
    @State private var showIconPicker = false
    @State private var paletteHeight: CGFloat = 150

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
            helpRow
            Divider()
            chipArea
            paletteResizeHandle
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
            // SwiftUI sheets don't expose a resizable style mask by default;
            // grab the key window (the sheet itself) and opt in.
            DispatchQueue.main.async {
                NSApplication.shared.keyWindow?.styleMask.insert(.resizable)
            }
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

    // MARK: - Help

    private var helpRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text("Build your template by adding chips from the palette. Drag chips to reorder them. Text chips hold literal content; coloured chips are dynamic placeholders resolved when copying.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
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

    // MARK: - Palette resize handle

    private var paletteResizeHandle: some View {
        PaletteResizeHandle(height: $paletteHeight, minHeight: 80, maxHeight: 320)
            .frame(height: 8)
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
        .frame(height: paletteHeight)
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
        // Date
        case .currentDate:     return Segment(type: .currentDate,     args: ["YYYY-MM-DD"])
        case .currentTime:     return Segment(type: .currentTime,     args: ["HH:mm:ss"])
        case .currentDateTime: return Segment(type: .currentDateTime, args: ["YYYY-MM-DDTHH:mm:ss"])
        case .dateAdd:         return Segment(type: .dateAdd,         args: ["+1d"])
        case .quarterStart:    return Segment(type: .quarterStart)
        case .quarterEnd:      return Segment(type: .quarterEnd)
        // Interactive
        case .choice:          return Segment(type: .choice,          args: ["option1", "option2"])
        case .input:           return Segment(type: .input,           args: ["Label"])
        case .textArea:        return Segment(type: .textArea,        args: ["Text"])
        case .number:          return Segment(type: .number,          args: ["Amount"])
        case .toggle:          return Segment(type: .toggle,          args: ["Option", "Yes", "No"])
        // Random
        case .nanoId:          return Segment(type: .nanoId,          args: ["10"])
        case .random:          return Segment(type: .random,          args: ["100"])
        case .randomHex:       return Segment(type: .randomHex,       args: ["8"])
        case .lorem:           return Segment(type: .lorem,           args: ["5"])
        case .sequence:        return Segment(type: .sequence,        args: ["a", "b", "c"])
        // System
        case .env:             return Segment(type: .env,             args: ["VAR_NAME"])
        case .counter:         return Segment(type: .counter,         args: ["id"])
        case .clipLine:        return Segment(type: .clipLine,        args: ["1"])
        default:               return Segment(type: type)
        }
    }

    // MARK: - Preview

    private var previewText: String {
        var userValues: [String] = []
        for seg in segments where PlaceholderRegistry.shared.isInteractive(seg.type) {
            switch seg.type {
            case .choice:   userValues.append(seg.args.first ?? "")
            case .input:    userValues.append(seg.args.first ?? "Value")
            case .textArea: userValues.append(seg.args.first ?? "…")
            case .number:   userValues.append(seg.args.count > 1 ? seg.args[1] : "0")
            case .toggle:   userValues.append(seg.args.count > 2 ? seg.args[2] : "false")
            default:        userValues.append("")
            }
        }
        return (try? TemplateResolver.resolveAll(segments, userValues: userValues)) ?? draft.template
    }

    private var previewRow: some View {
        HStack {
            Text("Preview:").font(.caption).foregroundStyle(.secondary)
            Text(previewText)
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
        [SegmentType.currentDate, .currentTime, .currentDateTime,
         .quarterStart, .quarterEnd].contains(segment.type)
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
        case .quarterStart, .quarterEnd:
            return [
                DateFormatOption(label: "ISO 8601",   format: "YYYY-MM-DD"),
                DateFormatOption(label: "US",         format: "MM/DD/YYYY"),
                DateFormatOption(label: "European",   format: "DD.MM.YYYY"),
                DateFormatOption(label: "Compact",    format: "YYYYMMDD"),
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

// MARK: - PaletteResizeHandle

/// NSViewRepresentable drag handle that tracks the mouse in stable window
/// coordinates. SwiftUI's DragGesture re-measures translation in the view's
/// local space; when the VStack reflows as paletteHeight changes the handle
/// position shifts and the gesture reads spurious deltas, causing flicker.
/// Tracking in window space avoids that entirely.
struct PaletteResizeHandle: NSViewRepresentable {
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, minHeight: minHeight, maxHeight: maxHeight)
    }

    func makeNSView(context: Context) -> HandleNSView {
        HandleNSView(coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: HandleNSView, context: Context) {}

    // MARK: Coordinator

    final class Coordinator {
        @Binding var height: CGFloat
        let minHeight: CGFloat
        let maxHeight: CGFloat
        var startHeight: CGFloat = 0
        var startWindowY: CGFloat = 0

        init(height: Binding<CGFloat>, minHeight: CGFloat, maxHeight: CGFloat) {
            _height    = height
            self.minHeight = minHeight
            self.maxHeight = maxHeight
        }
    }

    // MARK: NSView

    final class HandleNSView: NSView {
        let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
            wantsLayer = true
        }
        required init?(coder: NSCoder) { fatalError() }

        override func draw(_ dirtyRect: NSRect) {
            // Hairline separator
            NSColor.separatorColor.setFill()
            NSRect(x: 0, y: bounds.midY.rounded() - 0.5,
                   width: bounds.width, height: 1).fill()
            // Pill grip
            let pill = NSRect(x: bounds.midX - 16, y: bounds.midY - 2, width: 32, height: 4)
            let path = NSBezierPath(roundedRect: pill, xRadius: 2, yRadius: 2)
            NSColor.tertiaryLabelColor.setFill()
            path.fill()
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeUpDown)
        }

        override func mouseDown(with event: NSEvent) {
            coordinator.startHeight  = coordinator.height
            coordinator.startWindowY = event.locationInWindow.y
        }

        override func mouseDragged(with event: NSEvent) {
            // NSView y-axis: positive = upward.
            // Dragging UP → deltaY > 0 → palette grows.
            // Dragging DOWN → deltaY < 0 → palette shrinks.
            let deltaY = event.locationInWindow.y - coordinator.startWindowY
            coordinator.height = max(coordinator.minHeight,
                                     min(coordinator.maxHeight,
                                         coordinator.startHeight + deltaY))
        }
    }
}
