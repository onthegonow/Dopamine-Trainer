import Foundation
import Combine

/// Manages user preferences and settings
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    private let defaults = UserDefaults.standard
    private let tagOrderKey = "tagOrder"
    
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
}
