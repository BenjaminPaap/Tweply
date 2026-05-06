import Foundation

// MARK: - ClipboardHistoryItem

struct ClipboardHistoryItem: Codable, Identifiable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isLikelyPassword: Bool
    let sourceAppBundleID: String?
    let sourceAppName: String?

    init(content: String, sourceAppBundleID: String? = nil, sourceAppName: String? = nil) {
        id = UUID()
        self.content = content
        timestamp = Date()
        isLikelyPassword = PasswordDetector.isLikelyPassword(content)
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
    }
}

// MARK: - PasswordDetector

enum PasswordDetector {
    /// Scores a string on multiple heuristics to decide if it looks like a password.
    static func isLikelyPassword(_ s: String) -> Bool {
        let len = s.count
        guard len >= 8, len <= 128 else { return false }

        // Multi-line content is not a password
        guard !s.contains("\n"), !s.contains("\r") else { return false }

        // Spaces are very unusual in passwords (passphrases are a rare exception)
        guard !s.contains(" ") else { return false }

        // Disqualify common non-password strings
        let lower = s.lowercased()
        for pfx in ["http://", "https://", "ftp://", "ssh://", "file://", "git://", "mailto:"] {
            if lower.hasPrefix(pfx) { return false }
        }
        if s.hasPrefix("/") || s.hasPrefix("~/") || s.hasPrefix("./") ||
           s.hasPrefix("C:\\") || s.hasPrefix("D:\\") { return false }

        // Disqualify plain email addresses
        let emailRegex = try? NSRegularExpression(pattern: #"^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$"#)
        if let r = emailRegex,
           r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil { return false }

        // Disqualify plain numeric / decimal strings
        if s.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" || $0 == "," }) { return false }

        // Score character-set variety
        var score = 0
        let scalars = s.unicodeScalars
        if scalars.contains(where: { CharacterSet.uppercaseLetters.contains($0) }) { score += 1 }
        if scalars.contains(where: { CharacterSet.lowercaseLetters.contains($0) }) { score += 1 }
        if scalars.contains(where: { CharacterSet.decimalDigits.contains($0) })    { score += 1 }
        let specials = CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:'\",.<>?/`~\\")
        if scalars.contains(where: { specials.contains($0) }) { score += 2 }

        // High unique-character ratio → higher entropy
        if Double(Set(s).count) / Double(len) > 0.55 { score += 1 }

        if len >= 12 { score += 1 }
        if len >= 20 { score += 1 }

        return score >= 4
    }

    /// Returns an obfuscated version showing only a few characters at each end.
    static func obfuscate(_ s: String) -> String {
        let n = s.count
        guard n > 4 else { return String(repeating: "•", count: n) }
        let vis    = max(1, min(3, n / 6))
        let middle = String(repeating: "•", count: min(n - vis * 2, 10))
        return String(s.prefix(vis)) + middle + String(s.suffix(vis))
    }
}
