import Foundation
import AppKit

// MARK: - VersionInfo

private struct VersionInfo: Codable {
    let version: String
    let url: String
}

// MARK: - UpdateChecker

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    private init() {}

    @Published private(set) var latestVersion: String?
    @Published private(set) var updateAvailable = false
    @Published private(set) var isChecking = false

    private let endpoint = URL(string: "https://tweply.paap.one/version.json")!
    private let lastCheckKey = "lastUpdateCheckDate"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var lastCheckDate: Date? {
        UserDefaults.standard.object(forKey: lastCheckKey) as? Date
    }

    // Runs a check only if the configured interval has elapsed since the last one.
    func checkIfDue(settings: AppSettings) {
        guard settings.checkForUpdatesEnabled else { return }
        let elapsed = Date().timeIntervalSince(lastCheckDate ?? .distantPast)
        guard elapsed >= TimeInterval(settings.updateCheckIntervalDays * 86_400) else { return }
        Task { await check() }
    }

    func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: endpoint)
            let info = try JSONDecoder().decode(VersionInfo.self, from: data)
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            latestVersion = info.version
            updateAvailable = info.version.isNewerThan(currentVersion)
        } catch {
            // Network unavailable or server unreachable — fail silently.
        }
    }
}

// MARK: - Semantic version comparison

private extension String {
    func isNewerThan(_ other: String) -> Bool {
        let lhs = split(separator: ".").compactMap { Int($0) }
        let rhs = other.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
