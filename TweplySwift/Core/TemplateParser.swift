import Foundation

enum TemplateParser {
    private static let regex: NSRegularExpression = {
        // Matches [TYPE:args|modifier] or plain text
        try! NSRegularExpression(pattern: #"\[([A-Z_]+)(?::([^|\]]+))?(?:\|([^\]]+))?\]|([^\[]+)"#)
    }()

    static func parse(_ template: String) -> [Segment] {
        var segments: [Segment] = []
        let ns = template as NSString
        let range = NSRange(location: 0, length: ns.length)

        for match in regex.matches(in: template, range: range) {
            let typeRange = match.range(at: 1)
            let argsRange = match.range(at: 2)
            let modRange  = match.range(at: 3)
            let textRange = match.range(at: 4)

            if typeRange.location != NSNotFound {
                let typeStr = ns.substring(with: typeRange)
                let type    = SegmentType(rawValue: typeStr) ?? .text

                var args: [String] = []
                if argsRange.location != NSNotFound {
                    args = ns.substring(with: argsRange).components(separatedBy: ",")
                }

                let modifier: String? = modRange.location != NSNotFound
                    ? ns.substring(with: modRange) : nil

                segments.append(Segment(type: type, value: nil, args: args, modifier: modifier))
            } else if textRange.location != NSNotFound {
                segments.append(Segment(type: .text, value: ns.substring(with: textRange)))
            }
        }

        return segments
    }

    static func stringify(_ segments: [Segment]) -> String {
        segments.map(\.templateString).joined()
    }
}
