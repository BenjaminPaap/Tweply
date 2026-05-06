import Foundation
import SwiftUI

// MARK: - SegmentType

enum SegmentType: String, Codable, CaseIterable {
    case text = "TEXT"
    // Date
    case currentDate = "CURRENTDATE"
    case currentTime = "CURRENTTIME"
    case currentDateTime = "CURRENTDATETIME"
    case currentYear = "CURRENTYEAR"
    case currentMonth = "CURRENTMONTH"
    case currentDay = "CURRENTDAY"
    case currentWeek = "CURRENTWEEK"
    case currentDayOfWeek = "CURRENTDAYOFWEEK"
    case currentTimestamp = "CURRENTTIMESTAMP"
    case dateAdd = "DATEADD"
    case quarterStart = "QUARTERSTART"
    case quarterEnd = "QUARTEREND"
    // Interactive
    case choice = "CHOICE"
    case input = "INPUT"
    case textArea = "TEXTAREA"
    case number = "NUMBER"
    case toggle = "TOGGLE"
    // Random
    case uuid = "UUID"
    case nanoId = "NANOID"
    case random = "RANDOM"
    case randomHex = "RANDOMHEX"
    case lorem = "LOREM"
    case sequence = "SEQUENCE"
    // System
    case username = "USERNAME"
    case hostname = "HOSTNAME"
    case platform = "PLATFORM"
    case env = "ENV"
    case clipboard = "CLIPBOARD"
    case counter = "COUNTER"
    case fullName = "FULLNAME"
    case localIP = "LOCALIP"
    case appName = "APPNAME"
    case gitBranch = "GITBRANCH"
    case clipLine = "CLIPLINE"
    case wordCount = "WORDCOUNT"
    case lineCount = "LINECOUNT"
    case trimmed = "TRIMMED"
    case urlEncode = "URLENCODE"
    case base64 = "BASE64"
    case sha256 = "SHA256"

    var isInteractive: Bool {
        [.choice, .input, .textArea, .number, .toggle].contains(self)
    }

    var category: SegmentCategory {
        switch self {
        case .text: return .text
        case .currentDate, .currentTime, .currentDateTime,
             .currentYear, .currentMonth, .currentDay,
             .currentWeek, .currentDayOfWeek, .currentTimestamp,
             .dateAdd, .quarterStart, .quarterEnd:
            return .date
        case .choice, .input, .textArea, .number, .toggle:
            return .interactive
        case .uuid, .nanoId, .random, .randomHex, .lorem, .sequence:
            return .random
        case .username, .hostname, .platform, .env, .clipboard, .counter,
             .fullName, .localIP, .appName, .gitBranch, .clipLine,
             .wordCount, .lineCount, .trimmed, .urlEncode, .base64, .sha256:
            return .system
        }
    }

    var color: Color { category.color }

    var shortName: String {
        switch self {
        case .text:             return ""
        case .currentDate:      return "Date"
        case .currentTime:      return "Time"
        case .currentDateTime:  return "DateTime"
        case .currentYear:      return "Year"
        case .currentMonth:     return "Month"
        case .currentDay:       return "Day"
        case .currentWeek:      return "Week"
        case .currentDayOfWeek: return "Weekday"
        case .currentTimestamp: return "Timestamp"
        case .dateAdd:          return "Date+Offset"
        case .quarterStart:     return "Quarter Start"
        case .quarterEnd:       return "Quarter End"
        case .choice:           return "Choice"
        case .input:            return "Input"
        case .textArea:         return "Text Area"
        case .number:           return "Number"
        case .toggle:           return "Toggle"
        case .uuid:             return "UUID"
        case .nanoId:           return "NanoID"
        case .random:           return "Random"
        case .randomHex:        return "Hex"
        case .lorem:            return "Lorem"
        case .sequence:         return "Sequence"
        case .username:         return "Username"
        case .hostname:         return "Hostname"
        case .platform:         return "Platform"
        case .env:              return "Env"
        case .clipboard:        return "Clipboard"
        case .counter:          return "Counter"
        case .fullName:         return "Full Name"
        case .localIP:          return "Local IP"
        case .appName:          return "App Name"
        case .gitBranch:        return "Git Branch"
        case .clipLine:         return "Clip Line"
        case .wordCount:        return "Word Count"
        case .lineCount:        return "Line Count"
        case .trimmed:          return "Trimmed"
        case .urlEncode:        return "URL Encode"
        case .base64:           return "Base64"
        case .sha256:           return "SHA256"
        }
    }
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
    var clipboardHistoryEnabled: Bool = true
    var maxClipboardHistoryItems: Int = 50
    var obfuscatePasswords: Bool = true
    var menuClipboardRows: Int = 8
    var templatesAboveClipboard: Bool = false
    var hotkeyEnabled: Bool = true
    var hotkeyKeyCode: Int = 8          // C
    var hotkeyModifiers: Int = 768      // Cmd+Shift (256+512)
}
