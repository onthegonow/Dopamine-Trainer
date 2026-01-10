import Foundation
import Combine

/// Manages user preferences and settings
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    private let defaults = UserDefaults.standard
    private let tagOrderKey = "tagOrder"
    private let hiddenTagsKey = "hiddenTags"
    
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
    
    // MARK: - Emoji-to-Tag Mapping
    //
    // ARCHITECTURE NOTE:
    // - Emojis are stored in the database (CloudKit) as raw strings (e.g., "🚬", "🎮").
    // - Default emoji-to-label mappings live in code (see UrgeTag.defaultCatalog).
    // - This user settings storage ONLY contains custom mappings:
    //   1. When a user changes the label for a default emoji (e.g., "🚬" -> "cigarettes" instead of "substance")
    //   2. When a user adds a completely new emoji that's not in the default catalog
    // - When resolving an emoji to a label, check custom mappings first, then fall back to defaults.
    
    private let emojiTagMappingKey = "emojiTagMapping"
    
    /// Emoji-to-label mapping array. Only stores user customizations, not defaults.
    /// Format: Dictionary where key is emoji string and value is custom label.
    func getEmojiTagMapping() -> [String: String] {
        return defaults.dictionary(forKey: emojiTagMappingKey) as? [String: String] ?? [:]
    }
    
    /// Save or update a custom label for an emoji.
    /// This should ONLY be called when:
    /// 1. User changes the label for a default emoji, OR
    /// 2. User adds a new emoji not in the default catalog
    func saveEmojiTagMapping(emoji: String, label: String) {
        var mapping = getEmojiTagMapping()
        mapping[emoji] = label
        defaults.set(mapping, forKey: emojiTagMappingKey)
    }
    
    /// Get the label for an emoji, checking custom mappings first, then defaults.
    /// Returns nil if emoji is not found in either custom or default mappings.
    func labelForEmoji(_ emoji: String) -> String? {
        // Check custom mapping first
        let customMapping = getEmojiTagMapping()
        if let customLabel = customMapping[emoji] {
            return customLabel
        }
        
        // Fall back to default catalog
        if let defaultTag = UrgeTag.defaultCatalog.first(where: { $0.emoji == emoji }) {
            return defaultTag.label
        }
        
        return nil
    }
    
    /// Remove a custom mapping for an emoji (reverts to default if it exists in defaultCatalog)
    func clearEmojiTagMapping(forEmoji emoji: String) {
        var mapping = getEmojiTagMapping()
        mapping.removeValue(forKey: emoji)
        defaults.set(mapping, forKey: emojiTagMappingKey)
    }
    
    /// Clear all custom emoji mappings (reverts all to defaults)
    func clearAllEmojiTagMappings() {
        defaults.removeObject(forKey: emojiTagMappingKey)
    }
    
    // MARK: - Legacy Support (deprecated keys)
    
    @available(*, deprecated, message: "Use emojiTagMapping instead")
    private let customTagCatalogKey = "customTagCatalog"
    
    /// Migrate old customTagCatalog to new emojiTagMapping if needed
    func migrateCustomTagCatalogIfNeeded() {
        guard let oldCatalog = defaults.dictionary(forKey: customTagCatalogKey) as? [String: String],
              !oldCatalog.isEmpty else {
            return
        }
        
        // Copy to new key
        var newMapping = getEmojiTagMapping()
        for (emoji, label) in oldCatalog {
            if newMapping[emoji] == nil {
                newMapping[emoji] = label
            }
        }
        defaults.set(newMapping, forKey: emojiTagMappingKey)
        
        // Clear old key
        defaults.removeObject(forKey: customTagCatalogKey)
        print("✅ Migrated \(oldCatalog.count) custom tag mappings to new storage")
    }
}
