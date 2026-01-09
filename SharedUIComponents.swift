import SwiftUI
import UniformTypeIdentifiers

// Shared timer label to ensure consistent styling and sizing across views
struct TimerLabelView: View {
    let text: String
    let fontSize: CGFloat
    let width: CGFloat
    var alignment: Alignment = .leading

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: width, alignment: alignment)
            .monospacedDigit()
    }
}

// Emoji toggle button with tooltip
struct TagToggleButton: View {
    let tag: UrgeTag
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Text(tag.emoji)
                .font(.system(size: 28))
                .opacity(isSelected ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .help(tag.label)
    }
}

// Inline tag toggles row with a leading '+' button and drag-to-reorder support
struct InlineTagToggles: View {
    let entryId: UUID
    let selectedTags: [UrgeTag]
    let onAddTap: () -> Void

    @State private var draggingTag: UrgeTag?
    @State private var dropTargetTag: UrgeTag?
    @State private var tagOrder: [UrgeTag] = []
    
    private let preferences = UserPreferences.shared

    // Build the full list of tags maintaining user's custom order
    private var orderedTags: [UrgeTag] {
        // If we have a custom order, use it
        if !tagOrder.isEmpty {
            var result = tagOrder
            // Add any new tags from selectedTags that aren't in our order yet
            for tag in selectedTags {
                if !result.contains(tag) {
                    result.append(tag)
                }
            }
            // Add any default catalog tags that aren't already present
            for defaultTag in UrgeTag.defaultCatalog {
                if !result.contains(defaultTag) {
                    result.append(defaultTag)
                }
            }
            return result
        } else {
            // Try to load saved order, otherwise use default initial order
            if let savedOrder = preferences.getTagOrder(for: entryId) {
                return buildOrderWithDefaults(from: savedOrder)
            } else if let defaultOrder = preferences.getDefaultTagOrder() {
                return buildOrderWithDefaults(from: defaultOrder)
            } else {
                // Fallback: start with selected tags, then add unselected defaults
                var result = selectedTags
                for defaultTag in UrgeTag.defaultCatalog {
                    if !result.contains(defaultTag) {
                        result.append(defaultTag)
                    }
                }
                return result
            }
        }
    }
    
    private func buildOrderWithDefaults(from savedOrder: [UrgeTag]) -> [UrgeTag] {
        var result = savedOrder
        // Add any new tags from selectedTags that aren't in our order yet
        for tag in selectedTags {
            if !result.contains(tag) {
                result.append(tag)
            }
        }
        // Add any default catalog tags that aren't already present
        for defaultTag in UrgeTag.defaultCatalog {
            if !result.contains(defaultTag) {
                result.append(defaultTag)
            }
        }
        return result
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: onAddTap) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .help("Add custom tag")
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                ForEach(orderedTags, id: \.self) { tag in
                    let isSelected = selectedTags.contains(tag)
                    
                    HStack(spacing: 4) {
                        // Show insertion indicator before this tag
                        if dropTargetTag == tag && draggingTag != tag {
                            InsertionIndicator()
                        }
                        
                        DraggableTagToggleButton(
                            tag: tag,
                            isSelected: isSelected,
                            isDragging: draggingTag == tag,
                            toggle: {
                                UrgeStore.shared.toggleTag(entryId: entryId, tag: tag)
                            }
                        )
                        .opacity(draggingTag == tag ? 0.5 : 1.0)
                        .onDrag {
                            draggingTag = tag
                            return NSItemProvider(object: "\(tag.label):\(tag.emoji)" as NSString)
                        }
                        .onDrop(of: [.text], delegate: TagDropDelegate(
                            destinationTag: tag,
                            tags: selectedTags,
                            draggingTag: $draggingTag,
                            dropTargetTag: $dropTargetTag,
                            onReorder: { source, destination in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    reorderTag(source, to: destination)
                                }
                            }
                        ))
                    }
                }
            }
        }
        .onAppear {
            // Load saved tag order on appearance
            if tagOrder.isEmpty {
                if let savedOrder = preferences.getTagOrder(for: entryId) {
                    tagOrder = buildOrderWithDefaults(from: savedOrder)
                } else if let defaultOrder = preferences.getDefaultTagOrder() {
                    tagOrder = buildOrderWithDefaults(from: defaultOrder)
                } else {
                    tagOrder = orderedTags
                }
            }
        }
    }

    private func reorderTag(_ source: UrgeTag, to destination: UrgeTag) {
        // Don't do anything if dropping on itself
        guard source != destination else {
            print("⚠️ Dropping on self, ignoring")
            return
        }
        
        // Update the visual order of all tags (both selected and unselected)
        var newOrder = orderedTags
        guard let sourceIndex = newOrder.firstIndex(of: source) else { return }
        newOrder.remove(at: sourceIndex)
        
        if let destIndex = newOrder.firstIndex(of: destination) {
            newOrder.insert(source, at: destIndex)
        } else {
            newOrder.append(source)
        }
        
        // Update our local order state
        tagOrder = newOrder
        
        // Persist the tag order
        preferences.saveTagOrder(for: entryId, tags: newOrder)
        preferences.saveDefaultTagOrder(newOrder) // Also save as default for new entries
        
        // Update the selected tags in the store (preserving the new order)
        let newSelectedTags = newOrder.filter { selectedTags.contains($0) || $0 == source }
        
        print("📝 Before reorder selected: \(selectedTags.map { $0.emoji })")
        print("📝 After reorder selected: \(newSelectedTags.map { $0.emoji })")
        print("📝 Full order: \(newOrder.map { $0.emoji })")
        print("💾 Saved tag order to preferences")
        
        UrgeStore.shared.reorderTags(entryId: entryId, tags: newSelectedTags)
    }
}

// Drop delegate for tag reordering
struct TagDropDelegate: DropDelegate {
    let destinationTag: UrgeTag
    let tags: [UrgeTag]
    @Binding var draggingTag: UrgeTag?
    @Binding var dropTargetTag: UrgeTag?
    let onReorder: (UrgeTag, UrgeTag) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggingTag = draggingTag else { return false }
        
        print("🔄 Performing drop: \(draggingTag.label) -> \(destinationTag.label)")
        
        // Perform the reorder
        onReorder(draggingTag, destinationTag)
        
        // Reset dragging state
        self.draggingTag = nil
        self.dropTargetTag = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingTag = draggingTag else { return }
        guard draggingTag != destinationTag else { return }
        
        // Show insertion indicator
        dropTargetTag = destinationTag
    }
    
    func dropExited(info: DropInfo) {
        // Hide insertion indicator
        dropTargetTag = nil
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// Tag button that supports drag appearance
struct DraggableTagToggleButton: View {
    let tag: UrgeTag
    let isSelected: Bool
    let isDragging: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Text(tag.emoji)
                .font(.system(size: 28))
                .opacity(isSelected ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .help(tag.label)
        .opacity(isDragging ? 0.5 : 1.0)
    }
}

// Read-only inline tag chips (for history rows)
struct InlineTagChips: View {
    let tags: [UrgeTag]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag.emoji)
                        .help(tag.label)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
    }
}
// Visual indicator showing where a dragged tag will be inserted
struct InsertionIndicator: View {
    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 3, height: 36)
            .cornerRadius(1.5)
            .shadow(color: .accentColor.opacity(0.5), radius: 3, x: 0, y: 0)
    }
}

