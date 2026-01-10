//
//  Dopamine_TrainerApp.swift
//  Dopamine Trainer
//
//  Auto-generated from spec by assistant
//

import SwiftUI

@main
struct Dopamine_TrainerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ActiveTimersPage()
        }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = MenuBarController.shared
        
        // Migrate legacy custom tag catalog to new emoji-tag mapping structure
        UserPreferences.shared.migrateCustomTagCatalogIfNeeded()
        
        // At app launch, configure CloudKit and (optionally) start the incremental poller
        // to keep local history in sync without waiting for a specific view to appear.
        // Configure CloudKit and start polling at app launch
        CloudKitPublicSyncService.shared.containerIdentifier = FeatureFlags.Sync.containerIdentifier
        Task {
            do {
                try await CloudKitPublicSyncService.shared.configure()
                // Perform an initial fetch and replace local history so UI has data immediately
                let events = try await CloudKitPublicSyncService.shared.fetchCravingHistory(limit: 100)
                let mapped = events.map { $0.asUrgeEntryModel() }
                await MainActor.run {
                    UrgeStore.shared.replaceHistoryFromCloud(mapped)
                }
                // Always-on polling (core app behavior)
                UrgeStore.shared.ensureCloudPollingStarted(interval: FeatureFlags.Sync.pollInterval)
            } catch {
                print("[App] ❌ CloudKit configure/fetch error at launch: \(error)")
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

