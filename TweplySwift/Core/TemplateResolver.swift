import Foundation

enum TemplateResolver {
    static func requiresInteraction(_ segments: [Segment]) -> Bool {
        segments.contains { PlaceholderRegistry.shared.isInteractive($0.type) }
    }

    static func interactiveDescriptors(_ segments: [Segment]) -> [FieldDescriptor] {
        segments.compactMap { PlaceholderRegistry.shared.descriptor(for: $0) }
    }

    static func resolveAll(_ segments: [Segment], userValues: [String] = []) throws -> String {
        var idx    = 0
        var result = ""

        for segment in segments {
            let raw: String
            if segment.type == .text {
                raw = segment.value ?? ""
            } else if PlaceholderRegistry.shared.isInteractive(segment.type) {
                raw = idx < userValues.count ? userValues[idx] : ""
                idx += 1
            } else {
                raw = try PlaceholderRegistry.shared.resolve(segment)
            }
            result += Transforms.apply(raw, modifier: segment.modifier)
        }

        return result
    }
}
