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

struct UrgeTag: Codable, Equatable, Hashable, Transferable {
    var label: String   // tooltip text (e.g., "substance")
    var emoji: String   // visible emoji only (e.g., "🚬")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }

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
