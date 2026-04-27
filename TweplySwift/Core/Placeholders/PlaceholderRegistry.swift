import Foundation

typealias StaticResolver = @Sendable (Segment) throws -> String

struct FieldDescriptor: Sendable {
    enum Kind: Sendable {
        case select(options: [String])
        case input(label: String)
    }
    let kind: Kind
}

final class PlaceholderRegistry: @unchecked Sendable {
    static let shared = PlaceholderRegistry()
    private init() {}

    private var staticResolvers:   [SegmentType: StaticResolver] = [:]
    private var interactiveDescs:  [SegmentType: @Sendable (Segment) -> FieldDescriptor] = [:]

    func register(_ type: SegmentType, resolver: @escaping StaticResolver) {
        staticResolvers[type] = resolver
    }

    func registerInteractive(_ type: SegmentType, descriptor: @escaping @Sendable (Segment) -> FieldDescriptor) {
        interactiveDescs[type] = descriptor
    }

    func resolve(_ segment: Segment) throws -> String {
        guard let resolver = staticResolvers[segment.type] else {
            throw PlaceholderError.unknownType(segment.type.rawValue)
        }
        return try resolver(segment)
    }

    func descriptor(for segment: Segment) -> FieldDescriptor? {
        interactiveDescs[segment.type]?(segment)
    }

    func isInteractive(_ type: SegmentType) -> Bool {
        interactiveDescs[type] != nil
    }
}

enum PlaceholderError: Error, LocalizedError {
    case unknownType(String)

    var errorDescription: String? {
        switch self {
        case .unknownType(let t): "Unknown placeholder type: \(t)"
        }
    }
}
