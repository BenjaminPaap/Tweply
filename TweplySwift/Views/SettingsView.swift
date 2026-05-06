import SwiftUI
import ServiceManagement

// MARK: - Root container (shown inside the SwiftUI Settings scene)

struct SettingsView: View {
    var body: some View {
        TabView {
            TemplatesTab()
                .tabItem { Label("Templates", systemImage: "rectangle.stack") }

            ClipboardTab()
                .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }

            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
        }
    }
}

// MARK: - Templates Tab

struct TemplatesTab: View {
    @State private var templates: [Template] = []
    @State private var editingTemplate: Template? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            templateList
        }
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 380, maxHeight: .infinity)
        .sheet(item: $editingTemplate) { tmpl in
            TemplateEditorView(
                template: tmpl,
                onSave: { saved in
                    if let idx = templates.firstIndex(where: { $0.id == saved.id }) {
                        templates[idx] = saved
                    } else {
                        templates.append(saved)
                    }
                    DataStore.shared.saveTemplates(templates)
                    editingTemplate = nil
                },
                onCancel: { editingTemplate = nil }
            )
        }
        .onAppear {
            templates = DataStore.shared.loadTemplates()
        }
    }

    private var toolbar: some View {
        HStack {
            Spacer()
            Button("Import") {
                DataStore.shared.importTemplates { imported in
                    templates = imported
                    DataStore.shared.saveTemplates(templates)
                }
            }
            Button("Export") { DataStore.shared.exportTemplates(templates) }
            Menu {
                Button("Add Template")  { editingTemplate = Template() }
                Divider()
                Button("Add Separator") {
                    templates.append(.separator())
                    DataStore.shared.saveTemplates(templates)
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .menuStyle(.borderedButton)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var templateList: some View {
        List {
            ForEach(templates) { tmpl in
                if tmpl.isSeparator {
                    SeparatorRowView(onDelete: {
                        templates.removeAll { $0.id == tmpl.id }
                        DataStore.shared.saveTemplates(templates)
                    })
                } else {
                    TemplateRowView(
                        template: tmpl,
                        onEdit:   { editingTemplate = tmpl },
                        onDelete: {
                            templates.removeAll { $0.id == tmpl.id }
                            DataStore.shared.saveTemplates(templates)
                        }
                    )
                }
            }
            .onMove { from, to in
                templates.move(fromOffsets: from, toOffset: to)
                DataStore.shared.saveTemplates(templates)
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Clipboard Tab

struct ClipboardTab: View {
    @State private var settings: AppSettings = AppSettings()
    @State private var historyCount: Int = 0
    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            Section("History") {
                Toggle("Enable clipboard history", isOn: $settings.clipboardHistoryEnabled)
                    .onChange(of: settings.clipboardHistoryEnabled) { _, _ in
                        DataStore.shared.saveSettings(settings)
                    }

                if settings.clipboardHistoryEnabled {
                    Toggle("Obfuscate likely passwords in menu", isOn: $settings.obfuscatePasswords)
                        .onChange(of: settings.obfuscatePasswords) { _, _ in
                            DataStore.shared.saveSettings(settings)
                        }

                    Picker("Store up to", selection: $settings.maxClipboardHistoryItems) {
                        Text("25 items").tag(25)
                        Text("50 items").tag(50)
                        Text("100 items").tag(100)
                        Text("200 items").tag(200)
                    }
                    .onChange(of: settings.maxClipboardHistoryItems) { _, _ in
                        DataStore.shared.saveSettings(settings)
                    }

                    Picker("Show in menu", selection: $settings.menuClipboardRows) {
                        Text("5 rows").tag(5)
                        Text("8 rows").tag(8)
                        Text("10 rows").tag(10)
                        Text("15 rows").tag(15)
                    }
                    .onChange(of: settings.menuClipboardRows) { _, _ in
                        DataStore.shared.saveSettings(settings)
                    }
                }
            }

            if settings.clipboardHistoryEnabled {
                Section {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear All History", systemImage: "trash")
                    }
                    .disabled(historyCount == 0)
                    .confirmationDialog(
                        "Clear Clipboard History?",
                        isPresented: $showClearConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Clear All History", role: .destructive) {
                            ClipboardManager.shared.clearAll()
                            historyCount = 0
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("All entries will be permanently deleted. This cannot be undone.")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            settings     = DataStore.shared.loadSettings()
            historyCount = ClipboardManager.shared.items.count
        }
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @State private var settings: AppSettings = AppSettings()

    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                Toggle("Enable global shortcut", isOn: $settings.hotkeyEnabled)
                    .onChange(of: settings.hotkeyEnabled) { _, _ in
                        DataStore.shared.saveSettings(settings)
                    }

                if settings.hotkeyEnabled {
                    Picker("Shortcut", selection: hotkeyPresetBinding) {
                        Text("⌘⇧C").tag(0)
                        Text("⌘⇧V").tag(1)
                        Text("⌘⌥V").tag(2)
                        Text("⌃⌥V").tag(3)
                    }
                }
            }

            Section("Menu") {
                Toggle("Show templates above clipboard history", isOn: $settings.templatesAboveClipboard)
                    .onChange(of: settings.templatesAboveClipboard) { _, _ in
                        DataStore.shared.saveSettings(settings)
                    }
            }

            Section("Application") {
                Toggle("Launch at login", isOn: $settings.openAtLogin)
                    .onChange(of: settings.openAtLogin) { _, enabled in
                        DataStore.shared.saveSettings(settings)
                        if #available(macOS 13, *) {
                            if enabled { try? SMAppService.mainApp.register() }
                            else       { try? SMAppService.mainApp.unregister() }
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { settings = DataStore.shared.loadSettings() }
    }

    // Maps (keyCode, modifiers) pairs to preset index and back
    private var hotkeyPresetBinding: Binding<Int> {
        Binding(
            get: {
                switch (settings.hotkeyKeyCode, settings.hotkeyModifiers) {
                case (8, 768):  return 0  // ⌘⇧C
                case (9, 768):  return 1  // ⌘⇧V
                case (9, 2816): return 2  // ⌘⌥V
                case (9, 6144): return 3  // ⌃⌥V
                default:        return 0
                }
            },
            set: { idx in
                switch idx {
                case 0: settings.hotkeyKeyCode = 8;  settings.hotkeyModifiers = 768   // ⌘⇧C
                case 1: settings.hotkeyKeyCode = 9;  settings.hotkeyModifiers = 768   // ⌘⇧V
                case 2: settings.hotkeyKeyCode = 9;  settings.hotkeyModifiers = 2816  // ⌘⌥V
                case 3: settings.hotkeyKeyCode = 9;  settings.hotkeyModifiers = 6144  // ⌃⌥V
                default: break
                }
                DataStore.shared.saveSettings(settings)
            }
        )
    }
}

// MARK: - SeparatorRowView

struct SeparatorRowView: View {
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Mirror template row: icon column (18pt)
            Image(systemName: "minus")
                .font(.system(size: 12))
                .foregroundStyle(.quaternary)
                .frame(width: 18, alignment: .center)

            // Mirror template row: name column (130pt)
            Text("Separator")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 130, alignment: .leading)

            // Mirror template row: vertical divider
            Divider().frame(height: 16)

            // Mirror template row: content area — a horizontal rule
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)

            // Single action
            Button("Delete", action: onDelete)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
        }
        .frame(height: 36)
    }
}

// MARK: - TemplateRowView

struct TemplateRowView: View {
    let template: Template
    let onEdit:   () -> Void
    let onDelete: () -> Void

    private var segments: [Segment] { TemplateParser.parse(template.template) }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Icon column — always 18pt so all rows align
            Group {
                if let icon = template.icon, !icon.isEmpty {
                    Image(systemName: icon).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "doc.text").foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: 13))
            .frame(width: 18, alignment: .center)

            // Name
            Text(template.name.isEmpty ? "Untitled" : template.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 130, alignment: .leading)

            Divider().frame(height: 16)

            // Inline preview: text segments as plain text, placeholders as short badges
            HStack(spacing: 2) {
                ForEach(segments) { seg in
                    if seg.type == .text {
                        Text(seg.value ?? "")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(seg.type.shortName)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(seg.type.color.opacity(0.12))
                            .foregroundStyle(seg.type.color)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()

            // Actions
            HStack(spacing: 4) {
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Delete", action: onDelete)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
            }
        }
        .frame(height: 36)
    }
}
