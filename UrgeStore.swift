import Foundation
import Combine
import SwiftUI

final class UrgeStore: ObservableObject {

    static let shared = UrgeStore()

    @Published private(set) var activeEntries: [UrgeEntryModel] = []
    @Published private(set) var historyEntries: [UrgeEntryModel] = []

    private let historyPageSize = 20
    private var allHistoryEntries: [UrgeEntryModel] = []

    private var cancellables = Set<AnyCancellable>()
    private var defaultTags: [UrgeTag] = []

    private init() {}

    func createActive() {
        let newEntry = UrgeEntryModel(id: UUID(), createdAt: Date(), resolvedAt: nil, status: .active, tags: defaultTags)
        activeEntries.insert(newEntry, at: 0)
    }

    func resolve(entryId: UUID, status: UrgeStatus, resolvedAt: Date = Date()) {
        guard let index = activeEntries.firstIndex(where: { $0.id == entryId }) else { return }
        var entry = activeEntries[index]
        entry.status = status
        if status == .faded {
            entry.resolvedAt = entry.createdAt.addingTimeInterval(24 * 3600)
        } else {
            entry.resolvedAt = resolvedAt
        }
        activeEntries.remove(at: index)
        insertHistoryEntry(entry)
    }

    func delete(entryId: UUID) {
        if let index = activeEntries.firstIndex(where: { $0.id == entryId }) {
            activeEntries.remove(at: index)
            // Clean up saved preferences for this entry
            UserPreferences.shared.clearTagOrder(for: entryId)
        }
    }

    func mostRecentActive() -> UrgeEntryModel? {
        activeEntries.first
    }

    // MARK: - Tag Management
    func toggleTag(entryId: UUID, tag: UrgeTag) {
        // Try active entries first
        if let index = activeEntries.firstIndex(where: { $0.id == entryId }) {
            var entry = activeEntries[index]
            if let existingIndex = entry.tags.firstIndex(of: tag) {
                entry.tags.remove(at: existingIndex)
            } else {
                entry.tags.append(tag)
            }
            activeEntries[index] = entry
            defaultTags = entry.tags
            return
        }
        
        // Try history entries
        if let index = allHistoryEntries.firstIndex(where: { $0.id == entryId }) {
            var entry = allHistoryEntries[index]
            if let existingIndex = entry.tags.firstIndex(of: tag) {
                entry.tags.remove(at: existingIndex)
            } else {
                entry.tags.append(tag)
            }
            allHistoryEntries[index] = entry
            // Update the displayed page as well
            updateHistoryPage(entry)
            return
        }
    }

    func addCustomTag(entryId: UUID, label: String) {
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Try active entries first
        if let index = activeEntries.firstIndex(where: { $0.id == entryId }) {
            var entry = activeEntries[index]
            // Use the first character as emoji if it's an emoji; otherwise show a generic label emoji
            let emoji = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
            let newTag = UrgeTag(label: label, emoji: emoji)
            UserPreferences.shared.saveCustomLabel(forEmoji: emoji, label: label)
            if entry.tags.contains(newTag) == false {
                entry.tags.append(newTag)
            }
            activeEntries[index] = entry
            defaultTags = entry.tags
            return
        }
        
        // Try history entries
        if let index = allHistoryEntries.firstIndex(where: { $0.id == entryId }) {
            var entry = allHistoryEntries[index]
            let emoji = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
            let newTag = UrgeTag(label: label, emoji: emoji)
            UserPreferences.shared.saveCustomLabel(forEmoji: emoji, label: label)
            if entry.tags.contains(newTag) == false {
                entry.tags.append(newTag)
            }
            allHistoryEntries[index] = entry
            // Update the displayed page as well
            updateHistoryPage(entry)
            return
        }
    }

    func addCustomTag(entryId: UUID, emoji: String, label: String) {
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        print("📝 UrgeStore.addCustomTag called for entry \(entryId) with emoji '\(emoji)' and label '\(label)'")
        
        // Try active entries first
        if let index = activeEntries.firstIndex(where: { $0.id == entryId }) {
            print("✅ Found entry in activeEntries at index \(index)")
            var entry = activeEntries[index]
            let newTag = UrgeTag(label: label, emoji: emoji)
            UserPreferences.shared.saveCustomLabel(forEmoji: emoji, label: label)
            if entry.tags.contains(newTag) == false {
                entry.tags.append(newTag)
                print("✅ Added tag '\(emoji)' to active entry, now has \(entry.tags.count) tags")
            } else {
                print("⚠️ Tag already exists in active entry")
            }
            activeEntries[index] = entry
            defaultTags = entry.tags
            return
        }
        
        // Try history entries
        if let index = allHistoryEntries.firstIndex(where: { $0.id == entryId }) {
            print("✅ Found entry in allHistoryEntries at index \(index)")
            var entry = allHistoryEntries[index]
            let newTag = UrgeTag(label: label, emoji: emoji)
            UserPreferences.shared.saveCustomLabel(forEmoji: emoji, label: label)
            if entry.tags.contains(newTag) == false {
                entry.tags.append(newTag)
                print("✅ Added tag '\(emoji)' to history entry, now has \(entry.tags.count) tags")
            } else {
                print("⚠️ Tag already exists in history entry")
            }
            allHistoryEntries[index] = entry
            // Update the displayed page as well
            updateHistoryPage(entry)
            return
        }
        
        print("❌ Entry not found in activeEntries or allHistoryEntries")
    }

    func reorderTags(entryId: UUID, tags: [UrgeTag]) {
        // Try active entries first
        if let index = activeEntries.firstIndex(where: { $0.id == entryId }) {
            var entry = activeEntries[index]
            entry.tags = tags
            activeEntries[index] = entry
            defaultTags = entry.tags
            return
        }
        
        // Try history entries
        if let index = allHistoryEntries.firstIndex(where: { $0.id == entryId }) {
            var entry = allHistoryEntries[index]
            entry.tags = tags
            allHistoryEntries[index] = entry
            // Update the displayed page as well
            updateHistoryPage(entry)
            return
        }
    }
    
    // Helper to update an entry in the displayed history page
    private func updateHistoryPage(_ updatedEntry: UrgeEntryModel) {
        if let pageIndex = historyEntriesPage.firstIndex(where: { $0.id == updatedEntry.id }) {
            historyEntriesPage[pageIndex] = updatedEntry
            print("✅ Updated entry in historyEntriesPage at index \(pageIndex)")
        }
    }

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case beatIt = "Beat it"
        case satisfied = "Satisfied"
        case faded = "Faded"

        var id: String { rawValue }
        var urgeStatuses: [UrgeStatus]? {
            switch self {
            case .all: return nil
            case .beatIt: return [.beatIt]
            case .satisfied: return [.satisfied]
            case .faded: return [.faded]
            }
        }
    }

    @Published var currentFilter: StatusFilter = .all
    @Published var historyEntriesPage: [UrgeEntryModel] = []

    private var currentPage: Int = 0

    func queryHistory(reset: Bool = false) {
        if reset {
            currentPage = 0
            historyEntriesPage = []
        }

        var filtered = allHistoryEntries
        if let filterStatuses = currentFilter.urgeStatuses {
            filtered = allHistoryEntries.filter { filterStatuses.contains($0.status) }
        }

        let start = currentPage * historyPageSize
        guard start < filtered.count else { return }

        let end = min(start + historyPageSize, filtered.count)
        let nextPageItems = Array(filtered[start..<end])
        if reset {
            historyEntriesPage = nextPageItems
        } else {
            historyEntriesPage.append(contentsOf: nextPageItems)
        }
        currentPage += 1
    }

    func loadMoreHistoryIfNeeded(currentItem: UrgeEntryModel?) {
        guard let currentItem = currentItem else { return }
        guard let currentIndex = historyEntriesPage.firstIndex(where: { $0.id == currentItem.id }) else { return }
        let threshold = max(historyEntriesPage.count - 5, 0)
        if currentIndex >= threshold {
            queryHistory()
        }
    }

    private func insertHistoryEntry(_ entry: UrgeEntryModel) {
        allHistoryEntries.insert(entry, at: 0)
        queryHistory(reset: true)
    }

    func loadDummyHistory() {
        let now = Date()
        allHistoryEntries = (1...50).map {
            let created = now.addingTimeInterval(TimeInterval(-$0 * 3600))
            var status: UrgeStatus = .beatIt
            if $0 % 3 == 0 { status = .satisfied }
            else if $0 % 7 == 0 { status = .faded }
            return UrgeEntryModel(id: UUID(), createdAt: created, resolvedAt: created.addingTimeInterval(300), status: status)
        }
        queryHistory(reset: true)
    }
}

