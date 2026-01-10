import Foundation
import Combine

final class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()

    @Published var isAdmin: Bool = false

    // Replace or extend this list with additional record names as needed.
    // Using the recordName observed in logs for the developer's Apple ID.
    private let allowedRecordNames: Set<String> = ["_87f5716d5f6e3a80903fb4034cfb59b4"]

    private init() {}

    /// Evaluate admin flag based on the currently configured CloudKit user.
    func setAdminFromCurrentCloudUser() {
        let current = CloudKitPublicSyncService.shared.currentUserRecordName
        if let current {
            let allowed = allowedRecordNames.contains(current)
            isAdmin = allowed
            print("[FeatureFlags] currentUserRecordName=\(current) -> isAdmin=\(allowed)")
        } else {
            isAdmin = false
            print("[FeatureFlags] currentUserRecordName unavailable; isAdmin=false")
        }
    }
}
