import Foundation

enum Transforms {
    static func apply(_ value: String, modifier: String?) -> String {
        guard let modifier else { return value }

        switch modifier {
        case "upper": return value.uppercased()
        case "lower": return value.lowercased()
        case "slug":
            return value
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
        case "alphanum":
            return value.unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .map { String($0) }
                .joined()
        default:
            if modifier.hasPrefix("allow:") {
                return filterAllow(value, pattern: String(modifier.dropFirst(6)))
            }
            return value
        }
    }

    private static func filterAllow(_ value: String, pattern: String) -> String {
        var allowed = CharacterSet()
        var i = pattern.startIndex
        while i < pattern.endIndex {
            let c = pattern[i]
            let next = pattern.index(after: i)
            if next < pattern.endIndex && pattern[next] == "-" {
                let afterDash = pattern.index(after: next)
                if afterDash < pattern.endIndex {
                    if let startScalar = c.unicodeScalars.first,
                       let endScalar = pattern[afterDash].unicodeScalars.first,
                       startScalar <= endScalar {
                        allowed.insert(charactersIn: startScalar...endScalar)
                    }
                    i = pattern.index(after: afterDash)
                    continue
                }
            }
            if let scalar = c.unicodeScalars.first { allowed.insert(scalar) }
            i = next
        }
        return value.unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
    }
}
