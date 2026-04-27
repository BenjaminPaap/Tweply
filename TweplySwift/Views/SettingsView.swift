import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var templates: [Template] = []
    @State private var settings:  AppSettings = AppSettings()
    @State private var editingTemplate: Template? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            templateList
            Divider()
            footer
        }
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
            settings  = DataStore.shared.loadSettings()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Templates")
                .font(.headline)
            Spacer()
            Button("Import") {
                DataStore.shared.importTemplates { imported in
                    templates = imported
                    DataStore.shared.saveTemplates(templates)
                }
            }
            Button("Export") { DataStore.shared.exportTemplates(templates) }
            Button {
                editingTemplate = Template()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Template List

    private var templateList: some View {
        List {
            ForEach(templates) { tmpl in
                TemplateRowView(
                    template: tmpl,
                    onEdit: { editingTemplate = tmpl },
                    onDelete: {
                        templates.removeAll { $0.id == tmpl.id }
                        DataStore.shared.saveTemplates(templates)
                    }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .onMove { from, to in
                templates.move(fromOffsets: from, toOffset: to)
                DataStore.shared.saveTemplates(templates)
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Toggle("Launch at login", isOn: $settings.openAtLogin)
                .onChange(of: settings.openAtLogin) { _, enabled in
                    DataStore.shared.saveSettings(settings)
                    applyLoginItem(enabled: enabled)
                }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func applyLoginItem(enabled: Bool) {
        if #available(macOS 13, *) {
            if enabled {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
}

// MARK: - TemplateRowView

struct TemplateRowView: View {
    let template: Template
    let onEdit:   () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.caption)

            Text(template.name)
                .frame(width: 130, alignment: .leading)
                .lineLimit(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(TemplateParser.parse(template.template)) { seg in
                        Text(seg.displayChipText)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(seg.type.color.opacity(0.15))
                            .foregroundStyle(seg.type.color)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button("Edit",   action: onEdit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Delete", action: onDelete)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}
