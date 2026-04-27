import Foundation
import SwiftUI

// MARK: - SegmentType

enum SegmentType: String, Codable, CaseIterable {
    case text = "TEXT"
    case currentDate = "CURRENTDATE"
    case currentTime = "CURRENTTIME"
    case currentDateTime = "CURRENTDATETIME"
    case currentYear = "CURRENTYEAR"
    case currentMonth = "CURRENTMONTH"
    case currentDay = "CURRENTDAY"
    case currentWeek = "CURRENTWEEK"
    case currentDayOfWeek = "CURRENTDAYOFWEEK"
    case currentTimestamp = "CURRENTTIMESTAMP"
    case choice = "CHOICE"
    case input = "INPUT"
    case uuid = "UUID"
    case nanoId = "NANOID"
    case random = "RANDOM"
    case randomHex = "RANDOMHEX"
    case username = "USERNAME"
    case hostname = "HOSTNAME"
    case platform = "PLATFORM"
    case env = "ENV"
    case clipboard = "CLIPBOARD"
    case counter = "COUNTER"

    var isInteractive: Bool { self == .choice || self == .input }

    var category: SegmentCategory {
        switch self {
        case .text: return .text
        case .currentDate, .currentTime, .currentDateTime,
             .currentYear, .currentMonth, .currentDay,
             .currentWeek, .currentDayOfWeek, .currentTimestamp:
            return .date
        case .choice, .input: return .interactive
        case .uuid, .nanoId, .random, .randomHex, .counter: return .random
        case .username, .hostname, .platform, .env, .clipboard: return .system
        }
    }

    var color: Color { category.color }
}

// MARK: - SegmentCategory

enum SegmentCategory: String, CaseIterable {
    case text = "Text"
    case date = "Date"
    case interactive = "Interactive"
    case random = "Random"
    case system = "System"

    var color: Color {
        switch self {
        case .text: return Color(nsColor: .secondaryLabelColor)
        case .date: return .orange
        case .interactive: return .purple
        case .random: return .green
        case .system: return .blue
        }
    }

    var types: [SegmentType] {
        SegmentType.allCases.filter { $0.category == self && $0 != .text }
    }
}

// MARK: - Segment

struct Segment: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var type: SegmentType
    var value: String?
    var args: [String] = []
    var modifier: String?

    enum CodingKeys: String, CodingKey {
        case id, type, value, args, modifier
    }

    var displayChipText: String {
        if type == .text { return value ?? "" }
        var s = type.rawValue
        if !args.isEmpty { s += ":\(args.joined(separator: ","))" }
        if let modifier { s += "|\(modifier)" }
        return s
    }

    var templateString: String {
        if type == .text { return value ?? "" }
        var s = "[\(type.rawValue)"
        if !args.isEmpty { s += ":\(args.joined(separator: ","))" }
        if let modifier { s += "|\(modifier)" }
        s += "]"
        return s
    }
}

// MARK: - Template

struct Template: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var template: String
    var icon: String?
    var isSeparator: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        template: String = "",
        icon: String? = nil,
        isSeparator: Bool = false
    ) {
        self.id = id
        self.name = name
        self.template = template
        self.icon = icon
        self.isSeparator = isSeparator
    }

    static func separator() -> Template {
        Template(id: UUID().uuidString, isSeparator: true)
    }

    // Backward-compatible decoding
    enum CodingKeys: String, CodingKey {
        case id, name, template, icon, isSeparator
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        name        = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        template    = try c.decodeIfPresent(String.self, forKey: .template) ?? ""
        icon        = try c.decodeIfPresent(String.self, forKey: .icon)
        isSeparator = try c.decodeIfPresent(Bool.self,   forKey: .isSeparator) ?? false
    }
}

// MARK: - AppSettings

struct AppSettings: Codable {
    var openAtLogin: Bool = false
}
