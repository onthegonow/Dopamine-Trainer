import Foundation
import CloudKit
import CoreGraphics

/// CloudKitPublicSyncService
///
/// SPEC: Public Database–backed sync for cross-device data that must not depend on a user's personal iCloud storage quota.
///
/// Goal
/// - Provide resilient sync for small but important app state using CloudKit's Public database with owner-only access rules.
/// - Avoid failures when a user has run out of their personal iCloud storage.
/// - Keep data private to the user by scoping records to their userRecordID and enforcing owner-only access in CloudKit Dashboard.
///
/// Data domains to support (initial scope)
/// 1) macOS window state: positions/sizes/fullscreen per window identifier.
/// 2) User preferences: versioned preferences with forward-compatibility for future keys.
/// 3) Cravings history: append-only event log of cravings for cross-device availability.
/// 4) Timers (future): active timer states for live sync across devices.
///
/// CloudKit placement
/// - Use CKContainer.publicCloudDatabase.
/// - Attach an `owner` field (CKRecord.Reference to the current user's record) on every record for per-user scoping.
/// - All queries are filtered by `owner == currentUserRef`.
///
/// Security model (CloudKit Dashboard)
/// - Record Types: PublicWindowState, PublicUserPreferences, PublicCravingEvent, PublicTimer.
/// - Set Read/Write permissions to "Only the record creator" or custom rule:
///     read:  record.creatorUserRecordID == userRecordID()
///     write: record.creatorUserRecordID == userRecordID()
/// - Disable unauthenticated public access.
/// - Consider server-side indexes:
///     - PublicWindowState: (owner, windowID)
///     - PublicUserPreferences: (owner)
///     - PublicCravingEvent: (owner, occurredAt DESC)
///     - PublicTimer: (owner, timerID)
///
/// Quotas/limits considerations
/// - Public DB usage counts toward the app container's quotas (not the user's storage). No per-user billing.
/// - Implement exponential backoff on CKError.requestRateLimited, .serviceUnavailable, .zoneBusy.
/// - Handle .notAuthenticated gracefully (user signed out of iCloud) by operating locally and retrying later.
///
/// Conflict resolution
/// - Window state: last-writer-wins by updatedAt timestamp; treat writes as idempotent per (owner, windowID).
/// - Preferences: last-writer-wins by version/updatedAt; treat as a single logical record per owner.
/// - Craving events: immutable append-only. Use globally unique eventID (UUID) to deduplicate.
/// - Timers: resolve by latest updatedAt, prefer active state; reconcile elapsed time deterministically.
///
/// Subscriptions (push sync)
/// - Create CKQuerySubscription per RecordType filtered on owner == current user.
/// - Use silent push to trigger background fetch; on receipt, fetch changed records and merge.
/// - Provide an idempotent "apply remote changes" entry point.
///
/// Integration plan (phased)
/// - Phase 1: Introduce stubs and schema; land owner scoping and basic save/fetch APIs.
/// - Phase 2: Implement persistence, conflict resolution, and subscriptions.
/// - Phase 3: Wire to app models (UrgeStore, preferences store, window management), replace local-only pathways.
///
/// NOTE: All methods are currently stubs (throwing NotImplemented). We'll fill these in after planning.

public enum PublicSyncStubError: Error {
    case notImplemented
}

public final class CloudKitPublicSyncService {
    // MARK: - Public API Surface (to be wired into app)

    public static let shared = CloudKitPublicSyncService()

    /// Stable per-install device identifier used for audit fields.
    public static var deviceID: String = {
        let key = "CloudKitPublicSyncService.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()

    /// CloudKit container identifier for this app family.
    /// Replace with your container id, e.g. "iCloud.com.yourcompany.yourcontainer".
    public var containerIdentifier: String = "iCloud.dopaminetrainer"

    /// Cached user record ID for scoping queries. Nil until configured.
    private var userRecordID: CKRecord.ID?

    /// Convenience access to the public database for the configured container.
    private var publicDB: CKDatabase {
        CKContainer(identifier: containerIdentifier).publicCloudDatabase
    }

    private init() {}

    // MARK: - Configuration

    /// Fetch and cache the current user's record ID. Must be called before owner-scoped operations.
    public func configure() async throws {
        // SPEC: Fetch userRecordID, create subscriptions if needed.
        // - If notAuthenticated: do not throw; surface to caller so UI can show "Sync unavailable".
        // - On success: cache userRecordID and ensure per-type subscriptions exist.
        let container = CKContainer(identifier: containerIdentifier)
        print("[CloudKit] Configuring for container: \(containerIdentifier)")
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            container.fetchUserRecordID { [weak self] userID, error in
                if let error = error as? CKError {
                    switch error.code {
                    case .notAuthenticated:
                        print("[CloudKit] Not authenticated to iCloud. Operating locally.")
                        cont.resume()
                    default:
                        print("[CloudKit] fetchUserRecordID error: \(error)")
                        cont.resume(throwing: error)
                    }
                    return
                }
                if let userID {
                    self?.userRecordID = userID
                    print("[CloudKit] Service connects. userRecordID=\(userID.recordName)")
                } else {
                    print("[CloudKit] fetchUserRecordID returned nil userID")
                }
                cont.resume()
            }
        }
    }

    // MARK: - macOS Window State

    /// Save or update a window state for the current user.
    public func saveWindowState(_ state: PublicWindowState) async throws {
        // SPEC:
        // - Upsert by (owner, windowID) as recordID: "win_\(windowID)".
        // - Fields: owner (Reference), windowID (String), stateJSON (String), updatedAt (Date).
        // - Conflict policy: last-writer-wins by updatedAt.
        throw PublicSyncStubError.notImplemented
    }

    /// Fetch all window states for the current user.
    public func fetchWindowStates() async throws -> [PublicWindowState] {
        // SPEC:
        // - Query PublicWindowState where owner == current user; return all.
        // - Consider filtering by platform if you store platform-specific keys.
        throw PublicSyncStubError.notImplemented
    }

    // MARK: - User Preferences

    /// Save the user's preferences (versioned payload).
    public func saveUserPreferences(_ prefs: PublicUserPreferences) async throws {
        // SPEC:
        // - Single record per owner: recordID: "prefs_\(ownerRecordName)".
        // - Fields: owner (Reference), version (Int64), payload (Bytes/String), updatedAt (Date).
        // - Conflict policy: last-writer-wins by version then updatedAt.
        throw PublicSyncStubError.notImplemented
    }

    /// Fetch the latest user preferences for the current user.
    public func fetchUserPreferences() async throws -> PublicUserPreferences? {
        // SPEC:
        // - Lookup by recordID if known; otherwise query by owner and take latest by updatedAt.
        throw PublicSyncStubError.notImplemented
    }

    // MARK: - Cravings History (append-only)

    /// Append a craving event (immutable) for the current user.
    public func appendCravingEvent(_ event: PublicCravingEvent) async throws {
        // SPEC:
        // - RecordID: "craving_\(event.eventID)" (UUID string).
        // - Fields: owner (Reference), eventID (String), occurredAt (Date), tags ([String]), intensity (Int64?), note (String?), deviceID (String), updatedAt (Date).
        // - No overwrites; if exists, treat as duplicate and ignore.
        print("[CloudKit] ⬆️ appendCravingEvent id=\(event.eventID) at \(event.occurredAt)")
        print("  tagCount: \(event.tags.count)")
        let ownerRef = try ownerReference()
        let record = makeRecord(from: event, ownerRef: ownerRef)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            publicDB.save(record) { _, error in
                if let ckErr = error as? CKError {
                    if ckErr.code == .serverRecordChanged {
                        print("[CloudKit] Duplicate craving event (already exists), ignoring")
                        cont.resume()
                    } else {
                        print("[CloudKit] Save craving error: \(ckErr)")
                        cont.resume(throwing: ckErr)
                    }
                    return
                }
                if let error { print("[CloudKit] Save craving unknown error: \(error)") }
                else { print("[CloudKit] ✅ Saved craving event \(event.eventID)") }
                cont.resume()
            }
        }
    }

    /// Update an existing craving event's tags and metadata.
    /// This fetches the existing record, updates its fields, and saves it back.
    public func updateCravingEvent(_ event: PublicCravingEvent) async throws {
        print("[CloudKit] 🔄 updateCravingEvent id=\(event.eventID)")
        print("  tagCount: \(event.tags.count)")
        print("  tags: \(event.tags)")
        
        let recordID = cravingRecordID(for: event.eventID)
        
        // Fetch the existing record first
        let existingRecord = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CKRecord, Error>) in
            publicDB.fetch(withRecordID: recordID) { record, error in
                if let error = error {
                    print("[CloudKit] Fetch error: \(error)")
                    cont.resume(throwing: error)
                    return
                }
                guard let record = record else {
                    print("[CloudKit] Record not found")
                    cont.resume(throwing: CKError(.unknownItem))
                    return
                }
                cont.resume(returning: record)
            }
        }
        
        // Update the tags and metadata
        let cleanTags = sanitizeTags(event.tags)
        existingRecord[PublicFieldKey.tags] = cleanTags as NSArray
        if let intensity = event.intensity { existingRecord[PublicFieldKey.intensity] = NSNumber(value: intensity) }
        if let note = event.note { existingRecord[PublicFieldKey.note] = note as CKRecordValue }
        existingRecord[PublicFieldKey.updatedAt] = event.updatedAt as CKRecordValue
        
        // Save the updated record
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            publicDB.save(existingRecord) { _, error in
                if let error = error {
                    print("[CloudKit] Update error: \(error)")
                    cont.resume(throwing: error)
                    return
                }
                print("[CloudKit] ✅ Updated craving event \(event.eventID)")
                cont.resume()
            }
        }
    }

    /// Fetch craving events since a given date (or all if nil).
    public func fetchCravingHistory(since date: Date? = nil, limit: Int = 500) async throws -> [PublicCravingEvent] {
        // SPEC:
        // - Query by owner, optionally filter occurredAt > date, sort DESC by occurredAt, limit results.
        let ownerRef = try ownerReference()
        var predicate = NSPredicate(format: "owner == %@", ownerRef)
        if let date {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, NSPredicate(format: "occurredAt > %@", date as NSDate)])
        }
        let query = CKQuery(recordType: PublicRecordType.cravingEvent, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: PublicFieldKey.occurredAt, ascending: false)]
        print("[CloudKit] ⬇️ fetchCravingHistory limit=\(limit) since=\(String(describing: date))")
        var results: [PublicCravingEvent] = []
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[PublicCravingEvent], Error>) in
            let op = CKQueryOperation(query: query)
            // Add desiredKeys to optimize fetch and ensure fields are available
            op.desiredKeys = [PublicFieldKey.eventID, PublicFieldKey.occurredAt, PublicFieldKey.tags, PublicFieldKey.intensity, PublicFieldKey.note, PublicFieldKey.deviceID, PublicFieldKey.updatedAt]
            
            op.resultsLimit = limit
            op.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    let rawTags = record[PublicFieldKey.tags]
                    print("  raw tags: type=\(type(of: rawTags)) value=\(String(describing: rawTags))")
                    if let model = self.cravingEvent(from: record) {
                        print("[CloudKit] ⬇️ cravingEvent id=\(model.eventID) occurredAt=\(model.occurredAt)")
                        print("  tagCount: \(model.tags.count)")
                        print("  tags: \(model.tags)")
                        print("  intensity: \(String(describing: model.intensity))")
                        print("  note: \(String(describing: model.note))")
                        print("  deviceID: \(model.deviceID)")
                        print("  updatedAt: \(model.updatedAt)")
                        if let json = record[PublicFieldKey.payloadJSON] as? String {
                            print("  payloadJSON: \(json)")
                        }
                        // Actually print eventJSON or rebuild:
                        if let json = record["eventJSON"] as? String {
                            print("  eventJSON: \(json)")
                        } else if let json = self.encodeJSON(model) {
                            print("  eventJSON(rebuilt): \(json)")
                        }

                        results.append(model)
                    }
                case .failure(let error):
                    print("[CloudKit] recordMatched error: \(error)")
                }
            }
            op.queryResultBlock = { finalResult in
                switch finalResult {
                case .success:
                    print("[CloudKit] ✅ fetched \(results.count) craving events")
                    cont.resume(returning: results)
                case .failure(let error):
                    print("[CloudKit] fetchCravingHistory error: \(error)")
                    cont.resume(throwing: error)
                }
            }
            self.publicDB.add(op)
        }
    }

    /// Delete multiple craving events by record IDs (Public DB)
    public func deleteCravingEvents(recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }
        print("[CloudKit] 🗑️ Deleting \(recordIDs.count) craving events")
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("[CloudKit] ✅ Deleted \(recordIDs.count) records")
                    cont.resume()
                case .failure(let error):
                    print("[CloudKit] ❌ Delete error: \(error)")
                    cont.resume(throwing: error)
                }
            }
            self.publicDB.add(op)
        }
    }

    // MARK: - Timers (future)

    /// Upsert an active timer state.
    public func upsertTimerState(_ state: PublicTimerState) async throws {
        // SPEC:
        // - RecordID: "timer_\(state.timerID)".
        // - Fields: owner, timerID, isRunning (Bool), startedAt (Date?), totalElapsed (Double), updatedAt (Date), deviceID (String).
        // - Conflict policy: prefer the record with most recent updatedAt; reconcile elapsed deterministically.
        throw PublicSyncStubError.notImplemented
    }

    /// Fetch all active timer states for the user.
    public func fetchTimerStates() async throws -> [PublicTimerState] {
        // SPEC:
        // - Query by owner; return active timers.
        throw PublicSyncStubError.notImplemented
    }

    // MARK: - Subscriptions / Push Handling

    /// Ensure CKQuerySubscriptions exist for all record types for the current user.
    public func ensureSubscriptions() async throws {
        // SPEC:
        // - Create per-type CKQuerySubscription with predicate owner == currentUserRef.
        // - Use silent push; set a stable subscriptionID per type.
        throw PublicSyncStubError.notImplemented
    }

    /// Handle incoming CloudKit push notification and fetch changes.
    public func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {
        // SPEC:
        // - Parse CKNotification; decide which record type changed.
        // - Fetch changed records (by serverChangeToken if using database subscription or via query if needed).
        // - Apply changes idempotently to local stores.
    }

    // MARK: - Mapping Helpers (Record <-> Model)

    /// Build an owner reference for the current user.
    private func ownerReference() throws -> CKRecord.Reference {
        // SPEC: return CKRecord.Reference(recordID: userRecordID, action: .none)
        guard let userRecordID else {
            throw CKError(.notAuthenticated)
        }
        return CKRecord.Reference(recordID: userRecordID, action: .none)
    }

    private func windowStateRecordID(for windowID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "win_\(windowID)")
    }

    private func preferencesRecordID() throws -> CKRecord.ID {
        // SPEC: Use deterministic record ID per owner, e.g. "prefs_\(userRecordID.recordName)"
        guard let userRecordID else { throw CKError(.notAuthenticated) }
        return CKRecord.ID(recordName: "prefs_\(userRecordID.recordName)")
    }

    private func cravingRecordID(for eventID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "craving_\(eventID)")
    }

    private func timerRecordID(for timerID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "timer_\(timerID)")
    }
}

// MARK: - Models (Public DB representations)

/// Window state persisted in Public DB (per window identifier).
public struct PublicWindowState: Identifiable, Hashable, Codable {
    public var id: String { windowID }
    public var windowID: String
    public var stateJSON: String // JSON-encoded geometry/state. Cross-platform safe.
    public var updatedAt: Date

    public init(windowID: String, stateJSON: String, updatedAt: Date = Date()) {
        self.windowID = windowID
        self.stateJSON = stateJSON
        self.updatedAt = updatedAt
    }
}

/// Versioned user preferences stored as a forward-compatible payload.
public struct PublicUserPreferences: Identifiable, Hashable, Codable {
    public var id: String { "prefs" }
    public var version: Int
    public var payloadJSON: String // JSON blob of key/value preferences.
    public var updatedAt: Date

    public init(version: Int, payloadJSON: String, updatedAt: Date = Date()) {
        self.version = version
        self.payloadJSON = payloadJSON
        self.updatedAt = updatedAt
    }
}

/// Append-only craving event persisted in Public DB.
public struct PublicCravingEvent: Identifiable, Hashable, Codable {
    public var id: String { eventID }
    public var eventID: String // UUID string
    public var occurredAt: Date
    public var tags: [String] // e.g., ["sugar", "late-night"]
    public var intensity: Int?
    public var note: String?
    public var deviceID: String
    public var updatedAt: Date

    public init(eventID: String = UUID().uuidString,
                occurredAt: Date,
                tags: [String],
                intensity: Int? = nil,
                note: String? = nil,
                deviceID: String,
                updatedAt: Date = Date()) {
        self.eventID = eventID
        self.occurredAt = occurredAt
        self.tags = tags
        self.intensity = intensity
        self.note = note
        self.deviceID = deviceID
        self.updatedAt = updatedAt
    }
}

/// Active timer state persisted in Public DB (future scope).
public struct PublicTimerState: Identifiable, Hashable, Codable {
    public var id: String { timerID }
    public var timerID: String
    public var isRunning: Bool
    public var startedAt: Date?
    public var totalElapsed: TimeInterval
    public var deviceID: String
    public var updatedAt: Date

    public init(timerID: String,
                isRunning: Bool,
                startedAt: Date?,
                totalElapsed: TimeInterval,
                deviceID: String,
                updatedAt: Date = Date()) {
        self.timerID = timerID
        self.isRunning = isRunning
        self.startedAt = startedAt
        self.totalElapsed = totalElapsed
        self.deviceID = deviceID
        self.updatedAt = updatedAt
    }
}

// MARK: - Record Type & Field Keys

public enum PublicRecordType {
    public static let windowState = "PublicWindowState"
    public static let userPreferences = "PublicUserPreferences"
    public static let cravingEvent = "PublicCravingEvent"
    public static let timerState = "PublicTimer"
}

public enum PublicFieldKey {
    // Common
    public static let owner = "owner"
    public static let updatedAt = "updatedAt"
    public static let deviceID = "deviceID"

    // Window State
    public static let windowID = "windowID"
    public static let stateJSON = "stateJSON"

    // Preferences
    public static let version = "version"
    public static let payloadJSON = "payloadJSON"

    // Craving Event
    public static let eventID = "eventID"
    public static let occurredAt = "occurredAt"
    public static let tags = "tags"
    public static let intensity = "intensity"
    public static let note = "note"

    // Timer
    public static let timerID = "timerID"
    public static let isRunning = "isRunning"
    public static let startedAt = "startedAt"
    public static let totalElapsed = "totalElapsed"
}

// MARK: - Mapping (Placeholders)

extension CloudKitPublicSyncService {
    // Window State
    fileprivate func makeRecord(from state: PublicWindowState, ownerRef: CKRecord.Reference) -> CKRecord {
        let record = CKRecord(recordType: PublicRecordType.windowState, recordID: windowStateRecordID(for: state.windowID))
        record[PublicFieldKey.owner] = ownerRef
        record[PublicFieldKey.windowID] = state.windowID as CKRecordValue
        record[PublicFieldKey.stateJSON] = state.stateJSON as CKRecordValue
        record[PublicFieldKey.updatedAt] = state.updatedAt as CKRecordValue
        return record
    }

    fileprivate func windowState(from record: CKRecord) -> PublicWindowState? {
        guard let windowID = record[PublicFieldKey.windowID] as? String,
              let stateJSON = record[PublicFieldKey.stateJSON] as? String,
              let updatedAt = record[PublicFieldKey.updatedAt] as? Date else {
            return nil
        }
        return PublicWindowState(windowID: windowID, stateJSON: stateJSON, updatedAt: updatedAt)
    }

    // Preferences
    fileprivate func makeRecord(from prefs: PublicUserPreferences, ownerRef: CKRecord.Reference, ownerID: CKRecord.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "prefs_\(ownerID.recordName)")
        let record = CKRecord(recordType: PublicRecordType.userPreferences, recordID: recordID)
        record[PublicFieldKey.owner] = ownerRef
        record[PublicFieldKey.version] = NSNumber(value: prefs.version)
        record[PublicFieldKey.payloadJSON] = prefs.payloadJSON as CKRecordValue
        record[PublicFieldKey.updatedAt] = prefs.updatedAt as CKRecordValue
        return record
    }

    fileprivate func preferences(from record: CKRecord) -> PublicUserPreferences? {
        guard let versionNum = record[PublicFieldKey.version] as? NSNumber,
              let payloadJSON = record[PublicFieldKey.payloadJSON] as? String,
              let updatedAt = record[PublicFieldKey.updatedAt] as? Date else {
            return nil
        }
        return PublicUserPreferences(version: versionNum.intValue, payloadJSON: payloadJSON, updatedAt: updatedAt)
    }

    // Craving Event
    fileprivate func makeRecord(from event: PublicCravingEvent, ownerRef: CKRecord.Reference) -> CKRecord {
        let record = CKRecord(recordType: PublicRecordType.cravingEvent, recordID: cravingRecordID(for: event.eventID))
        record[PublicFieldKey.owner] = ownerRef
        record[PublicFieldKey.eventID] = event.eventID as CKRecordValue
        record[PublicFieldKey.occurredAt] = event.occurredAt as CKRecordValue
        let cleanTags = sanitizeTags(event.tags)
        record[PublicFieldKey.tags] = cleanTags as NSArray
        if let intensity = event.intensity { record[PublicFieldKey.intensity] = NSNumber(value: intensity) }
        if let note = event.note { record[PublicFieldKey.note] = note as CKRecordValue }
        record[PublicFieldKey.deviceID] = event.deviceID as CKRecordValue
        record[PublicFieldKey.updatedAt] = event.updatedAt as CKRecordValue
        return record
    }

    fileprivate func cravingEvent(from record: CKRecord) -> PublicCravingEvent? {
        guard let eventID = record[PublicFieldKey.eventID] as? String,
              let occurredAt = record[PublicFieldKey.occurredAt] as? Date,
              let deviceID = record[PublicFieldKey.deviceID] as? String,
              let updatedAt = record[PublicFieldKey.updatedAt] as? Date else {
            return nil
        }
        let tags = decodeTags(from: record)
        let intensity = (record[PublicFieldKey.intensity] as? NSNumber)?.intValue
        let note = record[PublicFieldKey.note] as? String
        return PublicCravingEvent(eventID: eventID, occurredAt: occurredAt, tags: tags, intensity: intensity, note: note, deviceID: deviceID, updatedAt: updatedAt)
    }

    // Timer
    fileprivate func makeRecord(from timer: PublicTimerState, ownerRef: CKRecord.Reference) -> CKRecord {
        let record = CKRecord(recordType: PublicRecordType.timerState, recordID: timerRecordID(for: timer.timerID))
        record[PublicFieldKey.owner] = ownerRef
        record[PublicFieldKey.timerID] = timer.timerID as CKRecordValue
        record[PublicFieldKey.isRunning] = NSNumber(value: timer.isRunning)
        if let startedAt = timer.startedAt { record[PublicFieldKey.startedAt] = startedAt as CKRecordValue }
        record[PublicFieldKey.totalElapsed] = NSNumber(value: timer.totalElapsed)
        record[PublicFieldKey.deviceID] = timer.deviceID as CKRecordValue
        record[PublicFieldKey.updatedAt] = timer.updatedAt as CKRecordValue
        return record
    }

    fileprivate func timerState(from record: CKRecord) -> PublicTimerState? {
        guard let timerID = record[PublicFieldKey.timerID] as? String,
              let isRunningNum = record[PublicFieldKey.isRunning] as? NSNumber,
              let totalElapsedNum = record[PublicFieldKey.totalElapsed] as? NSNumber,
              let deviceID = record[PublicFieldKey.deviceID] as? String,
              let updatedAt = record[PublicFieldKey.updatedAt] as? Date else {
            return nil
        }
        let startedAt = record[PublicFieldKey.startedAt] as? Date
        return PublicTimerState(timerID: timerID, isRunning: isRunningNum.boolValue, startedAt: startedAt, totalElapsed: totalElapsedNum.doubleValue, deviceID: deviceID, updatedAt: updatedAt)
    }
    
    // Decode tags robustly from various possible CKRecord storage forms
    fileprivate func decodeTags(from record: CKRecord) -> [String] {
        // Primary path: Array<String>
        if let tags = record[PublicFieldKey.tags] as? [String] {
            return sanitizeTags(tags)
        }
        // Alternate: Array<NSString>
        if let nsTags = record[PublicFieldKey.tags] as? [NSString] {
            return sanitizeTags(nsTags.map { String($0) })
        }
        // Single String (older schema or incorrect field type)
        if let single = record[PublicFieldKey.tags] as? String {
            // Try JSON array first
            if let data = single.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String] {
                return sanitizeTags(json)
            }
            // Fallback: split on commas if present, otherwise return single element
            let parts = single.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count > 1 {
                return sanitizeTags(parts.filter { !$0.isEmpty })
            } else if !single.isEmpty {
                return sanitizeTags([single])
            }
            return []
        }
        // Data containing JSON array (defensive)
        if let data = record[PublicFieldKey.tags] as? Data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return sanitizeTags(json)
        }
        return []
    }

    // Ensure tags match local format: trimmed, non-empty, deduplicated, and Unicode-normalized
    fileprivate func sanitizeTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in tags {
            // Trim whitespace/newlines
            var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.isEmpty { continue }
            // Normalize Unicode (canonical precomposed form)
            s = (s as NSString).precomposedStringWithCanonicalMapping
            // Deduplicate while preserving order
            if !seen.contains(s) {
                seen.insert(s)
                result.append(s)
            }
        }
        return result
    }

    // Helper to encode model to JSON string for logging
    fileprivate func encodeJSON<T: Encodable>(_ model: T) -> String? {
        do {
            let data = try JSONEncoder().encode(model)
            return String(data: data, encoding: .utf8)
        } catch {
            print("[CloudKit] JSON encode error: \(error)")
            return nil
        }
    }
}

// MARK: - Notes for Integration
/// - Replace containerIdentifier with your real iCloud container ID shared by your apps.
/// - After implementing methods, call `await CloudKitPublicSyncService.shared.configure()` on app launch.
/// - macOS window states: serialize geometry (frame, screen, isFullscreen) into `stateJSON`.
/// - Preferences: mirror your local preferences store into `payloadJSON` (keep a schema version).
/// - Cravings history: bridge from your app's domain model to `PublicCravingEvent`.
/// - Timers: when you are ready, wire `PublicTimerState` to your timer engine.

