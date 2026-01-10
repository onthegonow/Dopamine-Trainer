import Foundation
import Combine
import SwiftUI

/// UrgeStore
/// - Manages local active and history entries.
/// - Bridges to CloudKit via CloudKitPublicSyncService.
/// - Supports incremental polling with a saved cursor (cloudLastSyncDate) and merges new events
///   into local history on the main actor, then refreshes the paged view.
final class UrgeStore: ObservableObject {

    static let shared = UrgeStore()

    @Published private(set) var activeEntries: [UrgeEntryModel] = []
    @Published private(set) var historyEntries: [UrgeEntryModel] = []

    private let historyPageSize = 20
    private var allHistoryEntries: [UrgeEntryModel] = []

    private var cancellables = Set<AnyCancellable>()
    private var defaultTags: [UrgeTag] = []
    
    private var isCloudPollingActive: Bool = false
    private var cloudPollTimer: Timer?

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
        
        // After resolving locally, append a CloudKit event and then trigger a merge to capture any missing events.
        Task {
            let event = makePublicCravingEvent(from: entry)
            print("[App] ➡️ (resolve) sending event:")
            print("  id=\(event.eventID)")
            print("  occurredAt=\(event.occurredAt)")
            print("  tags=\(event.tags)")
            print("  tagCount=\(event.tags.count)")
            print("  intensity=\(String(describing: event.intensity))")
            print("  note=\(String(describing: event.note))")
            print("  deviceID=\(event.deviceID)")
            print("  updatedAt=\(event.updatedAt)")
            do {
                let encoder = JSONEncoder()
                if #available(iOS 13.0, macOS 10.15, *) { encoder.dateEncodingStrategy = .iso8601 }
                let data = try encoder.encode(event)
                if let json = String(data: data, encoding: .utf8) { print("  eventJSON: \(json)") }
            } catch {
                print("  eventJSON: <encode error> \(error)")
            }
            do {
                try await CloudKitPublicSyncService.shared.appendCravingEvent(event)
                print("[App] ✅ (resolve) event saved to CloudKit")
                await MainActor.run {
                    if let idx = self.allHistoryEntries.firstIndex(where: { $0.id == entry.id }) {
                        var updatedEntry = self.allHistoryEntries[idx]
                        updatedEntry.cloudEventID = event.eventID
                        self.allHistoryEntries[idx] = updatedEntry
                        self.updateHistoryPage(updatedEntry)
                        print("[CloudMerge] linked local entry \(entry.id) to cloudEventID=\(event.eventID)")
                    }
                }
                // After saving, kick off a merge to pull any missing events
                self.pollCloudAndMerge(limit: 100)
            } catch {
                print("[App] ❌ (resolve) CloudKit error: \(error)")
            }
        }
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
            
            // Sync the updated tags back to CloudKit
            syncHistoryEntryToCloudKit(entry)
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
            
            // Only save to user preferences if this is a NEW emoji (not in default catalog)
            if !UrgeTag.defaultCatalog.contains(where: { $0.emoji == emoji }) {
                UserPreferences.shared.saveEmojiTagMapping(emoji: emoji, label: label)
            }
            
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
            
            // Only save to user preferences if this is a NEW emoji (not in default catalog)
            if !UrgeTag.defaultCatalog.contains(where: { $0.emoji == emoji }) {
                UserPreferences.shared.saveEmojiTagMapping(emoji: emoji, label: label)
            }
            
            if entry.tags.contains(newTag) == false {
                entry.tags.append(newTag)
            }
            allHistoryEntries[index] = entry
            // Update the displayed page as well
            updateHistoryPage(entry)
            
            // Sync the updated tags back to CloudKit
            syncHistoryEntryToCloudKit(entry)
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
            
            // Check if this is a custom mapping (not in default catalog, or different label than default)
            let isCustomMapping: Bool
            if let defaultTag = UrgeTag.defaultCatalog.first(where: { $0.emoji == emoji }) {
                // Emoji exists in defaults - only save if label is different
                isCustomMapping = (defaultTag.label != label)
            } else {
                // New emoji not in defaults - always save
                isCustomMapping = true
            }
            
            if isCustomMapping {
                UserPreferences.shared.saveEmojiTagMapping(emoji: emoji, label: label)
                print("💾 Saved custom emoji-tag mapping: '\(emoji)' -> '\(label)'")
            } else {
                print("ℹ️ Using default mapping, not saving to preferences")
            }
            
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
            
            // Check if this is a custom mapping (not in default catalog, or different label than default)
            let isCustomMapping: Bool
            if let defaultTag = UrgeTag.defaultCatalog.first(where: { $0.emoji == emoji }) {
                // Emoji exists in defaults - only save if label is different
                isCustomMapping = (defaultTag.label != label)
            } else {
                // New emoji not in defaults - always save
                isCustomMapping = true
            }
            
            if isCustomMapping {
                UserPreferences.shared.saveEmojiTagMapping(emoji: emoji, label: label)
                print("💾 Saved custom emoji-tag mapping: '\(emoji)' -> '\(label)'")
            } else {
                print("ℹ️ Using default mapping, not saving to preferences")
            }
            
            if entry.tags.contains(newTag) == false {
                entry.tags.append(newTag)
                print("✅ Added tag '\(emoji)' to history entry, now has \(entry.tags.count) tags")
            } else {
                print("⚠️ Tag already exists in history entry")
            }
            allHistoryEntries[index] = entry
            // Update the displayed page as well
            updateHistoryPage(entry)
            
            // Sync the updated tags back to CloudKit
            syncHistoryEntryToCloudKit(entry)
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
            
            // Sync the updated tags back to CloudKit
            syncHistoryEntryToCloudKit(entry)
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

    // Helper to sync a history entry back to CloudKit after local modifications
    private func syncHistoryEntryToCloudKit(_ entry: UrgeEntryModel) {
        // Only sync if this entry has a cloud event ID (i.e., it exists in CloudKit)
        guard let cloudEventID = entry.cloudEventID else {
            print("[Sync] ⚠️ Entry \(entry.id) has no cloudEventID, skipping CloudKit update")
            return
        }
        
        Task {
            do {
                // Build the updated event from the local entry
                let event = makePublicCravingEvent(from: entry, eventID: cloudEventID)
                
                print("[Sync] 🔄 Syncing entry \(entry.id) to CloudKit")
                print("  cloudEventID: \(cloudEventID)")
                print("  tags: \(entry.tags.map { $0.emoji })")
                
                // Update the CloudKit record with the new tags
                try await CloudKitPublicSyncService.shared.updateCravingEvent(event)
                
                print("[Sync] ✅ Successfully synced entry \(entry.id) to CloudKit")
            } catch {
                print("[Sync] ❌ Failed to sync entry \(entry.id) to CloudKit: \(error)")
            }
        }
    }
    
    // Build a PublicCravingEvent from an entry (with explicit eventID for updates)
    private func makePublicCravingEvent(from entry: UrgeEntryModel, eventID: String? = nil) -> PublicCravingEvent {
        let tags = entry.tags.map { $0.emoji } // CloudKit stores only emojis
        let note = "status=\(entry.status.rawValue), tags=\(entry.tags.map { $0.label }.joined(separator: ","))"
        let device = CloudKitPublicSyncService.deviceID
        let occurred = entry.createdAt
        let updated = entry.resolvedAt ?? Date()
        
        return PublicCravingEvent(
            eventID: eventID ?? entry.id.uuidString,
            occurredAt: occurred,
            tags: tags,
            intensity: nil,
            note: note,
            deviceID: device,
            updatedAt: updated
        )
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
        // Also try to merge any remote events that may have appeared
        pollCloudAndMerge(limit: 20)
    }
    
    // Replace entire history with entries fetched from CloudKit and refresh paging
    func replaceHistoryFromCloud(_ entries: [UrgeEntryModel]) {
        self.allHistoryEntries = entries
        self.queryHistory(reset: true)
        print("[App] 📒 Replaced full history with \(entries.count) items from CloudKit")
    }

    func loadDummyHistory() {
        let now = Date()
        allHistoryEntries = (1...50).map {
            let created = now.addingTimeInterval(TimeInterval(-$0 * 3600))
            var status: UrgeStatus = .beatIt
            if $0 % 3 == 0 { status = .satisfied }
            else if $0 % 7 == 0 { status = .faded }
            
            // Add some random tags for testing
            var tags: [UrgeTag] = []
            let availableTags = UrgeTag.defaultCatalog
            let tagCount = Int.random(in: 1...3)
            for _ in 0..<tagCount {
                if let randomTag = availableTags.randomElement(), !tags.contains(randomTag) {
                    tags.append(randomTag)
                }
            }
            
            // Vary duration based on status
            let duration: TimeInterval
            switch status {
            case .beatIt: duration = TimeInterval.random(in: 300...7200) // 5 min to 2 hours
            case .satisfied: duration = TimeInterval.random(in: 60...1800) // 1 min to 30 min
            case .faded: duration = 24 * 3600
            case .active: duration = 0
            }
            
            return UrgeEntryModel(
                id: UUID(),
                createdAt: created,
                resolvedAt: created.addingTimeInterval(duration),
                status: status,
                tags: tags
            )
        }
        queryHistory(reset: true)
    }
    
    // MARK: - Summary Support
    
    /// Get summary stats for a given time slice
    func summaryStats(for timeSlice: SummaryTimeSlice) -> CravingSummaryStats {
        let range = timeSlice.dateRange
        let filtered = allHistoryEntries.filter {
            $0.createdAt >= range.start && $0.createdAt <= range.end
        }
        return CravingSummaryStats(timeSlice: timeSlice, entries: filtered)
    }
    
    /// Provides read-only access to all history entries for summary calculations
    var allHistoryEntriesForSummary: [UrgeEntryModel] {
        allHistoryEntries
    }
    
    // Internal setter used by minimal CloudKit integration to replace history
    fileprivate func setAllHistoryEntries(_ entries: [UrgeEntryModel]) {
        self.allHistoryEntries = entries
        self.queryHistory(reset: true)
    }

    // MARK: - Cloud Merge & Polling

    // Incremental sync cursor: last "occurredAt" seen. When nil, a full (bounded by limit) fetch is performed.
    private var cloudLastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "cloudLastSyncDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "cloudLastSyncDate") }
    }

    /// Poll CloudKit for events newer than the last sync cursor and merge any missing ones.
    /// - Parameter limit: Max records to fetch in one poll.
    /// - Behavior:
    ///   - Uses `cloudLastSyncDate` for incremental fetch.
    ///   - Only advances the cursor if events are received.
    ///   - Performs state mutations on the main actor and refreshes the paged view.
    func pollCloudAndMerge(limit: Int = 100) {
        Task {
            do {
                let since = cloudLastSyncDate
                print("[CloudMerge] Polling since=\(String(describing: since))")
                let events = try await CloudKitPublicSyncService.shared.fetchCravingHistory(since: since, limit: limit)
                print("[CloudMerge] Received \(events.count) events from CloudKit")
                var modelsToInsert: [UrgeEntryModel] = []
                for event in events {
                    let model = event.asUrgeEntryModel()
                    if !self.allHistoryEntries.contains(where: { $0.cloudEventID == event.eventID || $0.id.uuidString == event.eventID }) {
                        modelsToInsert.append(model)
                    }
                }
                if !modelsToInsert.isEmpty {
                    await MainActor.run {
                        for model in modelsToInsert {
                            self.allHistoryEntries.insert(model, at: 0)
                        }
                        print("[CloudMerge] Merged \(modelsToInsert.count) new events")
                        self.queryHistory(reset: true)
                    }
                } else {
                    print("[CloudMerge] No new events to merge")
                }
                // Advance last sync date only if we actually received events
                if let latest = events.map({ $0.occurredAt }).max() {
                    self.cloudLastSyncDate = latest
                }
            } catch {
                print("[CloudMerge] ❌ Error during poll: \(error)")
            }
        }
    }

    /// Start CloudKit polling once using the provided interval. Safe to call multiple times.
    /// Subsequent calls are ignored until the app restarts or polling is explicitly reconfigured.
    func ensureCloudPollingStarted(interval: TimeInterval) {
        guard !isCloudPollingActive else { return }
        isCloudPollingActive = true
        startCloudPolling(interval: interval)
    }

    /// Create or replace the repeating Timer that triggers incremental CloudKit polls.
    /// Also kicks off an immediate initial poll for faster first-load updates.
    func startCloudPolling(interval: TimeInterval = 30) {
        cloudPollTimer?.invalidate()
        cloudPollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pollCloudAndMerge()
        }
        // Kick off an initial poll immediately
        pollCloudAndMerge()
    }

}

// MARK: - PublicCravingEvent Conversion
extension PublicCravingEvent {
    /// Convert a CloudKit event to a local UrgeEntryModel.
    ///
    /// EMOJI-TAG MAPPING ARCHITECTURE:
    /// - CloudKit stores only emoji strings in the tags array (e.g., ["🚬", "🎮"])
    /// - This method resolves each emoji to its label by:
    ///   1. Checking UserPreferences for custom mappings first (user-defined labels)
    ///   2. Falling back to UrgeTag.defaultCatalog for default mappings
    ///   3. Using the emoji itself as label if no mapping exists
    ///
    /// This ensures that when events are pulled from CloudKit:
    /// - User customizations are preserved (e.g., if user renamed "🚬" to "cigarettes")
    /// - Default labels work out of the box for standard emojis
    /// - Unknown emojis still display (using the emoji itself as the label)
    func asUrgeEntryModel() -> UrgeEntryModel {
        // Convert CloudKit emoji strings to UrgeTag objects with proper labels
        let urgeTags = self.tags.map { emoji -> UrgeTag in
            // Try to get label from custom mappings first, then defaults, finally use emoji itself
            let label = UserPreferences.shared.labelForEmoji(emoji) ?? emoji
            return UrgeTag(label: label, emoji: emoji)
        }
        
        return UrgeEntryModel(
            id: UUID(uuidString: self.eventID) ?? UUID(),
            createdAt: self.occurredAt,
            resolvedAt: self.updatedAt,
            status: .beatIt, // Default status for imported events
            tags: urgeTags,
            cloudEventID: self.eventID
        )
    }
}


