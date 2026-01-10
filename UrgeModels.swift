import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - UrgeEntryModel

enum UrgeStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Active"
    case beatIt = "BeatIt"
    case satisfied = "Satisfied"
    case faded = "Faded"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .beatIt:
            return Color(red: 0.76, green: 0.94, blue: 0.78) // pastel green
        case .satisfied:
            return Color(red: 1.0, green: 0.8, blue: 0.8) // pastel red
        case .faded:
            return .gray
        case .active:
            return Color(red: 1.0, green: 0.95, blue: 0.7) // pastel yellow
        }
    }
}

// MARK: - UrgeTag
//
// EMOJI-TAG MAPPING ARCHITECTURE:
//
// 1. DATABASE STORAGE (CloudKit):
//    - Only emoji strings are stored (e.g., "🚬", "🎮", "🍰")
//    - No labels are stored in the database
//
// 2. DEFAULT MAPPINGS (Code):
//    - Live in UrgeTag.defaultCatalog below
//    - Provide standard emoji-to-label mappings (e.g., "🚬" -> "substance")
//
// 3. CUSTOM MAPPINGS (UserPreferences):
//    - Stored ONLY when user customizes a mapping:
//      a) Changes a default label (e.g., "🚬" -> "cigarettes" instead of "substance")
//      b) Adds a new emoji not in defaultCatalog
//    - Accessed via UserPreferences.shared.getEmojiTagMapping()
//
// 4. LABEL RESOLUTION:
//    - Check custom mappings first (UserPreferences.shared.labelForEmoji())
//    - Fall back to defaultCatalog if no custom mapping exists
//    - This ensures user customizations take precedence
//

struct UrgeTag: Codable, Equatable, Hashable, Transferable {
    var label: String   // Display label (e.g., "substance", "cigarettes")
    var emoji: String   // Emoji character (e.g., "🚬") - THIS is what gets stored in database

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }

    /// Default emoji-to-label mappings.
    /// These are the built-in tags available to all users.
    /// Custom user mappings are stored separately in UserPreferences.
    static let defaultCatalog: [UrgeTag] = [
        UrgeTag(label: "substance", emoji: "🚬"),
        UrgeTag(label: "games", emoji: "🎮"),
        UrgeTag(label: "sugar", emoji: "🍰"),
        UrgeTag(label: "porn", emoji: "🔞"),
        UrgeTag(label: "internet", emoji: "🌐"),
        UrgeTag(label: "chat", emoji: "💬")
    ]
}

struct UrgeEntryModel: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    var resolvedAt: Date?
    var status: UrgeStatus
    var tags: [UrgeTag] = []
    var cloudEventID: String? = nil

    var durationSeconds: TimeInterval {
        if status == .active {
            return Date().timeIntervalSince(createdAt)
        } else if status == .faded {
            return 24 * 3600
        } else if let resolved = resolvedAt {
            return resolved.timeIntervalSince(createdAt)
        } else {
            return 0
        }
    }
}

