import Foundation
import Combine

final class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()

    @Published var isAdmin: Bool = true

    private init() {}

    func setAdminFromCurrentCloudUser() {
        // Prefer a centralized debug gate so it's easy to toggle.
        if FeatureFlags.Debug.forceAdminToolbar {
            self.isAdmin = true
            return
        }
        // TODO: Hook into your CloudKit account status or custom logic to enable admin mode.
        // Example: compare current user's recordName against a whitelist.
        self.isAdmin = false
    }
}

extension FeatureFlags {
    /// Debug gates and developer-only toggles.
    enum Debug {
        #if DEBUG
        /// Show admin-only UI in DEBUG builds.
        static let forceAdminToolbar: Bool = true
        #else
        /// Hide admin-only UI in non-DEBUG builds.
        static let forceAdminToolbar: Bool = false
        #endif
    }

    /// Cloud sync configuration (container id and polling behavior). Always-on at launch (not feature-flagged).
    enum Sync {
        /// CloudKit container identifier used for all public DB operations.
        /// Set once at app launch (and in previews/tests as needed).
        static let containerIdentifier: String = "iCloud.dopaminetrainer"

        #if DEBUG
        /// Polling interval for CloudKit incremental fetches while running locally.
        /// Keep this short in DEBUG to see near-instant updates during development.
        static let pollInterval: TimeInterval = 5
        #else
        /// Polling interval for CloudKit incremental fetches in Release builds.
        /// Longer interval reduces load while keeping data reasonably fresh.
        static let pollInterval: TimeInterval = 30
        #endif
    }
}

