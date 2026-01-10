import Foundation
import Combine

/// Manages user preferences and settings
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    private let defaults = UserDefaults.standard
    private let tagOrderKey = "tagOrder"
    private let hiddenTagsKey = "hiddenTags"
    private let customTagCatalogKey = "customTagCatalog"
    
    private init() {}
    
    // MARK: - Tag Order Management
    
    /// Saves the tag order for a specific entry
    func saveTagOrder(for entryId: UUID, tags: [UrgeTag]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(tags) {
            defaults.set(encoded, forKey: tagOrderKey(for: entryId))
        }
    }
    
    /// Retrieves the saved tag order for a specific entry
    func getTagOrder(for entryId: UUID) -> [UrgeTag]? {
        guard let data = defaults.data(forKey: tagOrderKey(for: entryId)) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode([UrgeTag].self, from: data)
    }
    
    /// Saves the default/global tag order (used for new entries)
    func saveDefaultTagOrder(_ tags: [UrgeTag]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(tags) {
            defaults.set(encoded, forKey: tagOrderKey)
        }
    }
    
    /// Retrieves the default/global tag order
    func getDefaultTagOrder() -> [UrgeTag]? {
        guard let data = defaults.data(forKey: tagOrderKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode([UrgeTag].self, from: data)
    }
    
    /// Clears the saved tag order for a specific entry
    func clearTagOrder(for entryId: UUID) {
        defaults.removeObject(forKey: tagOrderKey(for: entryId))
    }
    
    private func tagOrderKey(for entryId: UUID) -> String {
        return "\(tagOrderKey)_\(entryId.uuidString)"
    }
    
    // MARK: - Hidden Tags Management
    
    /// Saves the hidden tags for a specific entry
    func saveHiddenTags(for entryId: UUID, tags: Set<UrgeTag>) {
        let encoder = JSONEncoder()
        let tagsArray = Array(tags)
        if let encoded = try? encoder.encode(tagsArray) {
            defaults.set(encoded, forKey: hiddenTagsKey(for: entryId))
        }
    }
    
    /// Retrieves the hidden tags for a specific entry
    func getHiddenTags(for entryId: UUID) -> Set<UrgeTag>? {
        guard let data = defaults.data(forKey: hiddenTagsKey(for: entryId)) else {
            return nil
        }
        let decoder = JSONDecoder()
        if let tagsArray = try? decoder.decode([UrgeTag].self, from: data) {
            return Set(tagsArray)
        }
        return nil
    }
    
    /// Saves the default/global hidden tags (used for new entries)
    func saveDefaultHiddenTags(_ tags: Set<UrgeTag>) {
        let encoder = JSONEncoder()
        let tagsArray = Array(tags)
        if let encoded = try? encoder.encode(tagsArray) {
            defaults.set(encoded, forKey: hiddenTagsKey)
        }
    }
    
    /// Retrieves the default/global hidden tags
    func getDefaultHiddenTags() -> Set<UrgeTag>? {
        guard let data = defaults.data(forKey: hiddenTagsKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        if let tagsArray = try? decoder.decode([UrgeTag].self, from: data) {
            return Set(tagsArray)
        }
        return nil
    }
    
    /// Clears the hidden tags for a specific entry
    func clearHiddenTags(for entryId: UUID) {
        defaults.removeObject(forKey: hiddenTagsKey(for: entryId))
    }
    
    private func hiddenTagsKey(for entryId: UUID) -> String {
        return "\(hiddenTagsKey)_\(entryId.uuidString)"
    }
    
    // MARK: - Custom Tag Catalog (emoji -> label)
    /// Save or update a custom label for an emoji
    func saveCustomLabel(forEmoji emoji: String, label: String) {
        var catalog = getCustomTagCatalog()
        catalog[emoji] = label
        defaults.set(catalog, forKey: customTagCatalogKey)
    }

    /// Retrieve a custom label for an emoji if present
    func labelForEmoji(_ emoji: String) -> String? {
        let catalog = getCustomTagCatalog()
        return catalog[emoji]
    }

    /// Retrieve the full custom catalog
    func getCustomTagCatalog() -> [String: String] {
        return defaults.dictionary(forKey: customTagCatalogKey) as? [String: String] ?? [:]
    }

    /// Clear a specific custom label
    func clearCustomLabel(forEmoji emoji: String) {
        var catalog = getCustomTagCatalog()
        catalog.removeValue(forKey: emoji)
        defaults.set(catalog, forKey: customTagCatalogKey)
    }

    /// Clear all custom labels
    func clearAllCustomLabels() {
        defaults.removeObject(forKey: customTagCatalogKey)
    }
}
