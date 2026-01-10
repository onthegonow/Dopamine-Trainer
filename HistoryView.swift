import SwiftUI

struct HistoryView: View {

    enum Page {
        case activeTimers
        case history
    }

    @ObservedObject private var store = UrgeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HistoryFilterStatusControl(selectedFilter: $store.currentFilter)
                .padding(.horizontal)
                .padding(.bottom, 16)

            HistoryTableHeader()
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            List(store.historyEntriesPage) { entry in
                HistoryRow(entry: entry)
                    .onAppear {
                        store.loadMoreHistoryIfNeeded(currentItem: entry)
                    }
            }
            .listStyle(.plain)
            .padding(.horizontal, 20)
        }
        .onChange(of: store.currentFilter) {
            store.queryHistory(reset: true)
        }
    }
}

struct HistoryFilterStatusControl: View {

    @Binding var selectedFilter: UrgeStore.StatusFilter

    var body: some View {
        Picker("", selection: $selectedFilter) {
            ForEach(UrgeStore.StatusFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .labelsHidden()
    }
}

struct HistoryTableHeader: View {
    var body: some View {
        HStack {
            Text("Date")
                .frame(width: 140, alignment: .leading)
                .font(.system(size: 13, weight: .semibold))
            
            Text("Tags")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 13, weight: .semibold))
            
            Text("Craving Time")
                .frame(width: 100, alignment: .trailing)
                .font(.system(size: 13, weight: .semibold))
            
            Text("Outcome")
                .frame(width: 160, alignment: .trailing)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.secondary)
    }
}

struct HistoryRow: View {
    let entry: UrgeEntryModel
    
    @State private var showingAddTag: Bool = false

    private var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: entry.createdAt)
    }

    private var durationString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: entry.durationSeconds) ?? "00:00:00"
    }

    private var statusColor: Color {
        entry.status.color
    }

    private var statusText: String {
        switch entry.status {
        case .beatIt: return "Beat it!"
        case .satisfied: return "Scratched the itch"
        case .faded: return "Faded (24h)"
        case .active: return "Active"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(timestampString)
                .frame(width: 140, alignment: .leading)
                .font(.system(size: 15))

            // Editable tags - shows only selected tags with full editing capability
            InlineTagToggles(entryId: entry.id, selectedTags: entry.tags, onAddTap: {
                showingAddTag = true
            }, isReadOnly: false, showOnlySelected: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            TimerLabelView(text: durationString, fontSize: 14, width: 100, alignment: .trailing)

            Text(statusText)
                .foregroundColor(statusColor)
                .fontWeight(.medium)
                .frame(width: 160, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingAddTag) {
            EmojiPickerSheet(onSelect: { emoji, label in
                UrgeStore.shared.addCustomTag(entryId: entry.id, emoji: emoji, label: label)
                showingAddTag = false
            }, onCancel: {
                showingAddTag = false
            })
        }
    }
}
