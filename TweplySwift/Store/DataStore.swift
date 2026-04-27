import Foundation
import AppKit
import UniformTypeIdentifiers

final class DataStore: @unchecked Sendable {
    static let shared = DataStore()
    private init() {}

    // MARK: - App Support directory

    private var appSupportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url  = base.appendingPathComponent("Tweply")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Templates

    private var templatesURL: URL { appSupportURL.appendingPathComponent("templates.json") }

    func loadTemplates() -> [Template] {
        guard let data      = try? Data(contentsOf: templatesURL),
              let templates = try? JSONDecoder().decode([Template].self, from: data)
        else {
            return [Template(id: "1", name: "Example", template: "test-[CURRENTDATE].[CHOICE:de,com,net]")]
        }
        return templates
    }

    func saveTemplates(_ templates: [Template]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(templates) else { return }
        try? data.write(to: templatesURL)
    }

    // MARK: - Settings

    private var settingsURL: URL { appSupportURL.appendingPathComponent("settings.json") }

    func loadSettings() -> AppSettings {
        guard let data     = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsURL)
    }

    // MARK: - Counters

    private var countersURL: URL  { appSupportURL.appendingPathComponent("counters.json") }
    private var counters: [String: Int] = [:]
    private var countersLoaded = false

    func incrementCounter(id: String, start: Int, step: Int) -> String {
        if !countersLoaded {
            countersLoaded = true
            if let data = try? Data(contentsOf: countersURL),
               let dict = try? JSONDecoder().decode([String: Int].self, from: data) {
                counters = dict
            }
        }
        let current      = counters[id] ?? start
        counters[id]     = current + step
        if let data = try? JSONEncoder().encode(counters) { try? data.write(to: countersURL) }
        return String(current)
    }

    // MARK: - Export / Import

    func exportTemplates(_ templates: [Template]) {
        let panel = NSSavePanel()
        panel.title                   = "Export Templates"
        panel.nameFieldStringValue    = "tweply-templates.json"
        panel.allowedContentTypes     = [.json]
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(templates) { try? data.write(to: url) }
        }
    }

    func importTemplates(completion: @escaping @MainActor ([Template]) -> Void) {
        let panel = NSOpenPanel()
        panel.title               = "Import Templates"
        panel.allowedContentTypes = [.json]
        panel.begin { result in
            guard result == .OK, let url = panel.url,
                  let data      = try? Data(contentsOf: url),
                  let templates = try? JSONDecoder().decode([Template].self, from: data)
            else { return }
            Task { @MainActor in completion(templates) }
        }
    }
}
