# Emoji-Tag Mapping Architecture

## Overview

This document describes how emoji-to-label mappings are handled throughout the application, ensuring clarity about what data is stored where and when.

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER SEES                                │
│                    Emoji + Label (e.g., "🚬 substance")          │
└─────────────────────────────────────────────────────────────────┘
                                   ↑
                                   │
                    ┌──────────────┴──────────────┐
                    │   Label Resolution Logic     │
                    │  (UserPreferences.shared.    │
                    │   labelForEmoji())           │
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                              │
         ┌──────────▼──────────┐      ┌──────────▼──────────┐
         │  Custom Mappings    │      │  Default Mappings   │
         │  (UserPreferences)  │      │  (Code)             │
         │                     │      │                     │
         │  Only stores:       │      │  UrgeTag            │
         │  1. Changed defaults│      │  .defaultCatalog    │
         │  2. New emojis      │      │                     │
         └─────────────────────┘      └─────────────────────┘

         ┌─────────────────────────────────────────┐
         │        Database (CloudKit)              │
         │                                         │
         │  Stores: ["🚬", "🎮", "🍰"]            │
         │  (ONLY emojis, NO labels)              │
         └─────────────────────────────────────────┘
```

## Three-Layer Architecture

### 1. Database Layer (CloudKit)
**What's Stored:** Only emoji strings
**Format:** Array of strings, e.g., `["🚬", "🎮", "🍰"]`
**Location:** `PublicCravingEvent.tags` field in CloudKit Public DB

```swift
// CloudKit record field:
record["tags"] = ["🚬", "🎮"] as NSArray
```

**Why:** This keeps the database normalized and lightweight. Labels are presentation concerns, not data.

### 2. Default Mappings Layer (Code)
**What's Stored:** Built-in emoji-to-label mappings
**Location:** `UrgeTag.defaultCatalog` in `UrgeModels.swift`

```swift
static let defaultCatalog: [UrgeTag] = [
    UrgeTag(label: "substance", emoji: "🚬"),
    UrgeTag(label: "games", emoji: "🎮"),
    UrgeTag(label: "sugar", emoji: "🍰"),
    // ...
]
```

**Purpose:** Provides standard labels that all users see by default. These are never saved to UserPreferences unless modified.

### 3. Custom Mappings Layer (UserPreferences)
**What's Stored:** User customizations only
**Location:** `UserPreferences.shared` → UserDefaults key `"emojiTagMapping"`
**Format:** Dictionary `[String: String]` (emoji → custom label)

**Stored when:**
1. User changes a default label (e.g., "🚬" → "cigarettes" instead of "substance")
2. User adds a completely new emoji not in `defaultCatalog`

**NOT stored when:**
- User uses a default emoji with its default label
- User selects from the emoji picker without customizing the label

```swift
// Example of what gets saved:
[
    "🚬": "cigarettes",  // Changed from default "substance"
    "🏋️": "gym"          // New emoji not in defaults
]
```

## Label Resolution Algorithm

When displaying an emoji, the system resolves its label using this priority:

```swift
func labelForEmoji(_ emoji: String) -> String? {
    // 1. Check custom mappings first (highest priority)
    let customMapping = getEmojiTagMapping()
    if let customLabel = customMapping[emoji] {
        return customLabel
    }
    
    // 2. Fall back to default catalog
    if let defaultTag = UrgeTag.defaultCatalog.first(where: { $0.emoji == emoji }) {
        return defaultTag.label
    }
    
    // 3. No mapping found - return nil (caller should use emoji itself)
    return nil
}
```

## Key Files and Their Roles

### UrgeModels.swift
- Defines `UrgeTag` struct with `emoji` and `label` properties
- Contains `defaultCatalog` with built-in mappings
- **Comprehensive documentation** explaining the three-layer architecture

### UserPreferences.swift
- Manages custom emoji-tag mappings in `emojiTagMapping` dictionary
- Provides `labelForEmoji()` for resolution logic
- Includes `saveEmojiTagMapping()` for storing customizations
- **Only saves custom mappings**, not defaults
- Includes migration logic for legacy `customTagCatalog` key

### EmojiPickerView.swift
- Displays emojis from `defaultCatalog` with tooltips showing labels
- Allows users to select emoji and optionally customize the label
- Automatically determines if label differs from default before saving
- **Annotated with architecture notes** at the top of the file

### UrgeStore.swift
- Contains `addCustomTag()` methods that intelligently save to UserPreferences
- Only saves to UserPreferences when mapping is custom (not default)
- Includes `PublicCravingEvent` extension with `asUrgeEntryModel()` that:
  - Receives emoji strings from CloudKit
  - Resolves labels using custom + default mappings
  - Creates `UrgeTag` objects for UI display

### CloudKitPublicSyncService.swift
- Stores and retrieves only emoji strings in `tags` field
- Uses robust `decodeTags()` to handle various CloudKit storage formats
- Never touches labels - purely emoji-based storage

### Dopamine_TrainerApp.swift
- Calls `migrateCustomTagCatalogIfNeeded()` at app launch
- Ensures legacy data is migrated to new architecture

## Benefits of This Architecture

1. **Normalized Database:** CloudKit stores minimal, unchanging data (emojis)
2. **Flexible Labels:** Users can customize labels without affecting data
3. **Efficient Storage:** Only custom mappings are saved, not every label
4. **Easy Defaults:** New default emojis can be added to code without migration
5. **Backward Compatible:** Migration handles old `customTagCatalog` format
6. **Performance:** Label resolution is fast with in-memory fallback chain

## Usage Examples

### Adding a Default Emoji (No Custom Mapping)
```swift
// User selects 🚬 from picker with default label "substance"
store.addCustomTag(entryId: id, emoji: "🚬", label: "substance")
// Result: Tag is added to entry, but NO data saved to UserPreferences
```

### Customizing a Default Emoji
```swift
// User selects 🚬 but changes label to "cigarettes"
store.addCustomTag(entryId: id, emoji: "🚬", label: "cigarettes")
// Result: Saved to UserPreferences: ["🚬": "cigarettes"]
```

### Adding a New Emoji
```swift
// User selects 🏋️ (not in defaultCatalog) with label "gym"
store.addCustomTag(entryId: id, emoji: "🏋️", label: "gym")
// Result: Saved to UserPreferences: ["🏋️": "gym"]
```

### Retrieving from CloudKit
```swift
// CloudKit returns: tags = ["🚬", "🎮"]
let event = PublicCravingEvent(tags: ["🚬", "🎮"], ...)
let model = event.asUrgeEntryModel()
// Result: model.tags = [
//   UrgeTag(emoji: "🚬", label: "cigarettes"),  // From custom mapping
//   UrgeTag(emoji: "🎮", label: "games")        // From default catalog
// ]
```

## Testing Checklist

- [ ] Default emojis display correct labels without any UserPreferences data
- [ ] Custom label changes persist across app restarts
- [ ] New emojis (not in defaults) save correctly
- [ ] CloudKit sync retrieves emoji-only data and resolves labels correctly
- [ ] Migration from old `customTagCatalog` works
- [ ] Clearing custom mapping reverts to default label
- [ ] No unnecessary data saved to UserPreferences

## Future Considerations

- Could add server-side label syncing for cross-device custom labels
- Could support per-language default catalogs for i18n
- Could add UI for managing custom mappings (view all, bulk reset, etc.)
