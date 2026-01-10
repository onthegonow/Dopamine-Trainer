# CloudKit Tag Sync Implementation

## Overview
This document describes the implementation of bidirectional CloudKit sync for emoji tag changes in history entries.

## Problem Statement
When users modify emojis/tags in the history list, the changes were only being saved locally. They were not syncing back to the corresponding CloudKit record, causing data inconsistency across devices.

## Solution Architecture

### 1. CloudKit Update Method (`CloudKitPublicSyncService`)
Added a new `updateCravingEvent()` method that:
- Fetches the existing CloudKit record by its `recordID`
- Updates the tags array and metadata fields
- Saves the modified record back to CloudKit
- Handles errors gracefully with detailed logging

```swift
public func updateCravingEvent(_ event: PublicCravingEvent) async throws
```

### 2. Local-to-CloudKit Sync Helper (`UrgeStore`)
Added `syncHistoryEntryToCloudKit()` method that:
- Checks if the entry has a `cloudEventID` (exists in CloudKit)
- Converts the local entry to a `PublicCravingEvent`
- Calls the CloudKit update method asynchronously
- Provides comprehensive logging for debugging

### 3. Integration Points
Modified three key methods in `UrgeStore` to trigger CloudKit sync when history entries are modified:

#### a) `toggleTag(entryId:tag:)`
- When toggling a tag on a history entry
- Calls `syncHistoryEntryToCloudKit()` after local update

#### b) `addCustomTag(entryId:emoji:label:)`
- When adding a new custom tag to a history entry
- Calls `syncHistoryEntryToCloudKit()` after local update

#### c) `reorderTags(entryId:tags:)`
- When reordering tags on a history entry
- Calls `syncHistoryEntryToCloudKit()` after local update

## Data Flow

### When User Modifies Tags in History:
1. **User Action**: User toggles, adds, or reorders tags in the history list
2. **Local Update**: `UrgeStore` updates `allHistoryEntries` and `historyEntriesPage`
3. **CloudKit Sync**: `syncHistoryEntryToCloudKit()` is called
4. **Record Fetch**: CloudKit record is fetched by `recordID`
5. **Record Update**: Tags array is updated with new emoji strings
6. **Record Save**: Updated record is saved back to CloudKit
7. **Cross-Device Sync**: CloudKit propagates changes to other devices via polling

### When Changes Come from Another Device:
1. **Polling**: App polls CloudKit periodically (via `pollCloudAndMerge()`)
2. **New Events**: Receives updated records with new `updatedAt` timestamps
3. **Merge**: Updates are merged into local `allHistoryEntries`
4. **UI Refresh**: History page is refreshed to show updated tags

## Key Design Decisions

### 1. Only Emojis Stored in CloudKit
Following the existing emoji-tag mapping architecture:
- CloudKit stores only emoji strings (e.g., `["🚬", "🎮", "🍰"]`)
- Labels are resolved locally from:
  - Custom user mappings (`UserPreferences`)
  - Default catalog (`UrgeTag.defaultCatalog`)
  - Fallback to emoji itself

### 2. CloudEventID Tracking
- Each `UrgeEntryModel` has an optional `cloudEventID` field
- This links local entries to their CloudKit records
- Only entries with `cloudEventID` can be synced back (prevents errors)

### 3. Asynchronous Sync
- CloudKit updates run in background `Task`
- UI remains responsive during sync
- Errors are logged but don't block the user

### 4. Active Entries vs History Entries
- Active entries (timers in progress) don't sync to CloudKit yet
- Only resolved history entries sync bidirectionally
- This prevents mid-timer state conflicts

## Testing Checklist

- [ ] Toggle tag on history entry → verify CloudKit record updated
- [ ] Add custom tag to history entry → verify CloudKit record updated
- [ ] Reorder tags on history entry → verify CloudKit record updated
- [ ] Modify entry on Device A → verify Device B receives changes after poll
- [ ] Verify entries without `cloudEventID` skip sync (no crashes)
- [ ] Verify active entries don't trigger CloudKit updates
- [ ] Check console logs for successful sync confirmation
- [ ] Test error handling when CloudKit is unavailable

## Future Enhancements

1. **Optimistic UI Updates**: Show tag changes immediately, rollback on CloudKit error
2. **Conflict Resolution**: Handle simultaneous edits from multiple devices
3. **Batch Updates**: Combine multiple tag changes into single CloudKit operation
4. **Real-time Sync**: Use CloudKit subscriptions instead of polling
5. **Offline Queue**: Queue changes when offline, sync when reconnected

## Related Files

- `CloudKitPublicSyncService.swift` - CloudKit interface and record mapping
- `UrgeStore.swift` - Local data store and sync orchestration
- `UrgeModels.swift` - Data models and emoji-tag architecture
- `HistoryView.swift` - UI for viewing and editing history
- `SharedUIComponents.swift` - Tag editing UI components

## Code References

### CloudKit Update Method
```swift
// CloudKitPublicSyncService.swift
public func updateCravingEvent(_ event: PublicCravingEvent) async throws
```

### Sync Helper
```swift
// UrgeStore.swift
private func syncHistoryEntryToCloudKit(_ entry: UrgeEntryModel)
```

### Integration Points
```swift
// UrgeStore.swift
func toggleTag(entryId: UUID, tag: UrgeTag)
func addCustomTag(entryId: UUID, emoji: String, label: String)
func reorderTags(entryId: UUID, tags: [UrgeTag])
```
