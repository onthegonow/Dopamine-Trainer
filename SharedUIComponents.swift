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
                .opacity(isSelected ? 1.0 : 0.3)
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
    var isReadOnly: Bool = false // New parameter for read-only mode
    var showOnlySelected: Bool = false // New parameter to show only selected tags

    @State private var draggingTag: UrgeTag?
    @State private var dropTargetTag: UrgeTag?
    @State private var tagOrder: [UrgeTag] = []
    @State private var isHoveringTrash: Bool = false
    @State private var hiddenTags: Set<UrgeTag> = [] // Track tags that were explicitly removed
    @State private var isInitialized: Bool = false // Track if we've loaded initial state
    
    private let preferences = UserPreferences.shared

    private func resolvedLabel(for tag: UrgeTag) -> String {
        // Prefer a user-custom label for this emoji if available
        if let custom = preferences.labelForEmoji(tag.emoji), !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom
        }
        return tag.label
    }
    
    // Build the full list of tags maintaining user's custom order
    private var orderedTags: [UrgeTag] {
        // Always use tagOrder if initialized
        guard !tagOrder.isEmpty else {
            return []
        }
        
        var result = tagOrder
        var seenEmojis = Set(result.map { $0.emoji }) // Track emojis to prevent duplicates
        
        // Add any new tags from selectedTags that aren't in our order yet
        for tag in selectedTags {
            if !result.contains(tag) && !hiddenTags.contains(tag) && !seenEmojis.contains(tag.emoji) {
                result.append(tag)
                seenEmojis.insert(tag.emoji)
            }
        }
        // Add any default catalog tags that aren't already present and not hidden
        for defaultTag in UrgeTag.defaultCatalog {
            if !result.contains(defaultTag) && !hiddenTags.contains(defaultTag) && !seenEmojis.contains(defaultTag.emoji) {
                result.append(defaultTag)
                seenEmojis.insert(defaultTag.emoji)
            }
        }
        
        // If showOnlySelected is true, filter to only selected tags
        if showOnlySelected {
            return result.filter { selectedTags.contains($0) }
        }
        
        return result
    }
    
    private func buildOrderWithDefaults(from savedOrder: [UrgeTag]) -> [UrgeTag] {
        var result = savedOrder
        var seenEmojis = Set(result.map { $0.emoji }) // Track emojis to prevent duplicates
        
        // Add any new tags from selectedTags that aren't in our order yet
        for tag in selectedTags {
            if !result.contains(tag) && !hiddenTags.contains(tag) && !seenEmojis.contains(tag.emoji) {
                result.append(tag)
                seenEmojis.insert(tag.emoji)
            }
        }
        // Add any default catalog tags that aren't already present and not hidden
        for defaultTag in UrgeTag.defaultCatalog {
            if !result.contains(defaultTag) && !hiddenTags.contains(defaultTag) && !seenEmojis.contains(defaultTag.emoji) {
                result.append(defaultTag)
                seenEmojis.insert(defaultTag.emoji)
            }
        }
        return result
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            // Show plus or trash icon based on drag state (only in editable mode)
            if !isReadOnly {
                Button(action: {
                    // Only trigger add action if not dragging
                    if draggingTag == nil {
                        onAddTap()
                    }
                }) {
                    Image(systemName: draggingTag != nil ? "trash.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(draggingTag != nil ? (isHoveringTrash ? .red : .orange) : .accentColor)
                        .frame(width: 32, height: 32) // Make the hit target consistent
                }
                .help(draggingTag != nil ? "Drop here to remove tag" : "Add custom tag")
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: draggingTag != nil)
                .animation(.easeInOut(duration: 0.15), value: isHoveringTrash)
                .onDrop(of: [.text], isTargeted: $isHoveringTrash) { providers in
                    guard let draggingTag = draggingTag else { return false }
                    print("🗑️ Drop received on trash can for tag: \(draggingTag.emoji)")
                    // Remove the tag
                    removeTag(draggingTag)
                    self.draggingTag = nil
                    self.isHoveringTrash = false
                    return true
                }
            }

            ForEach(orderedTags, id: \.emoji) { tag in
                let isSelected = selectedTags.contains(tag)
                
                HStack(spacing: 4) {
                    // Show insertion indicator before this tag (only in editable mode)
                    if !isReadOnly && dropTargetTag == tag && draggingTag != tag {
                        InsertionIndicator()
                    }
                    
                    if isReadOnly {
                        // Read-only: Simple emoji display with no interaction
                        Text(tag.emoji)
                            .font(.system(size: 28))
                            .opacity(isSelected ? 1.0 : 0.3)
                            .help(resolvedLabel(for: tag))
                    } else {
                        // Editable: Full drag and toggle functionality
                        // In showOnlySelected mode, all tags are selected so always show at full opacity
                        DraggableTagToggleButton(
                            tag: tag,
                            isSelected: isSelected,
                            isDragging: draggingTag == tag,
                            showAsSelected: showOnlySelected || isSelected, // Force full opacity if showOnlySelected
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
                            })
                        )
                        .help(resolvedLabel(for: tag))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            // Only initialize once
            guard !isInitialized else { return }
            
            // Load saved tag order
            let loadedOrder: [UrgeTag]
            if let savedOrder = preferences.getTagOrder(for: entryId) {
                loadedOrder = buildOrderWithDefaults(from: savedOrder)
            } else if let defaultOrder = preferences.getDefaultTagOrder() {
                loadedOrder = buildOrderWithDefaults(from: defaultOrder)
            } else {
                // Fallback: start with selected tags, then add unselected defaults
                var result = selectedTags
                for defaultTag in UrgeTag.defaultCatalog {
                    if !result.contains(defaultTag) {
                        result.append(defaultTag)
                    }
                }
                loadedOrder = result
            }
            
            // Load saved hidden tags (only in editable mode)
            let loadedHiddenTags: Set<UrgeTag>
            if !isReadOnly {
                if let savedHiddenTags = preferences.getHiddenTags(for: entryId) {
                    loadedHiddenTags = savedHiddenTags
                } else if let defaultHiddenTags = preferences.getDefaultHiddenTags() {
                    loadedHiddenTags = defaultHiddenTags
                } else {
                    loadedHiddenTags = []
                }
            } else {
                loadedHiddenTags = []
            }
            
            // Update state all at once after loading
            tagOrder = loadedOrder
            hiddenTags = loadedHiddenTags
            isInitialized = true
        }
    }

    private func removeTag(_ tag: UrgeTag) {
        print("🗑️ Removing tag: \(tag.emoji)")
        
        // If the tag is selected, deselect it first
        let wasSelected = selectedTags.contains(tag)
        
        // Update state
        withAnimation(.easeInOut(duration: 0.2)) {
            // Remove from visual order
            tagOrder.removeAll { $0 == tag }
            
            // Add to hidden tags so it doesn't get re-added
            hiddenTags.insert(tag)
        }
        
        // Persist tag order and hidden tags
        preferences.saveTagOrder(for: entryId, tags: tagOrder)
        preferences.saveDefaultTagOrder(tagOrder)
        preferences.saveHiddenTags(for: entryId, tags: hiddenTags)
        preferences.saveDefaultHiddenTags(hiddenTags)
        
        // Toggle the tag in store if it was selected (do this after animation to avoid conflicts)
        if wasSelected {
            Task { @MainActor in
                UrgeStore.shared.toggleTag(entryId: entryId, tag: tag)
            }
        }
        
        print("✅ Tag removed and hidden (persisted)")
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
    var showAsSelected: Bool = false // Override to show as selected regardless of actual state
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Text(tag.emoji)
                .font(.system(size: 28))
                .opacity((showAsSelected || isSelected) ? 1.0 : 0.3)
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
                ForEach(tags, id: \.emoji) { tag in
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

// Flow layout that wraps items to multiple lines
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX - spacing)
            }
            
            self.size.height = currentY + lineHeight
        }
    }
}

