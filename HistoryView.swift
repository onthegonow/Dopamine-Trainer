import SwiftUI

struct HistoryView: View {

    enum Page {
        case activeTimers
        case history
    }

    @ObservedObject private var store = UrgeStore.shared

    var body: some View {
        VStack {
            HistoryFilterStatusControl(selectedFilter: $store.currentFilter)
                .padding(.horizontal)

            List(store.historyEntriesPage) { entry in
                HistoryRow(entry: entry)
                    .onAppear {
                        store.loadMoreHistoryIfNeeded(currentItem: entry)
                    }
            }
            .listStyle(.plain)
            .padding(.horizontal, 20)
        }
        .onChange(of: store.currentFilter) { _ in
            store.queryHistory(reset: true)
        }
    }
}

struct HistoryFilterStatusControl: View {

    @Binding var selectedFilter: UrgeStore.StatusFilter

    var body: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(UrgeStore.StatusFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
}

struct HistoryRow: View {
    let entry: UrgeEntryModel

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
        case .beatIt: return "Beat it"
        case .satisfied: return "Satisfied"
        case .faded: return "Faded"
        case .active: return "Active"
        }
    }

    var body: some View {
        HStack {
            Text(timestampString)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 15))

            InlineTagChips(tags: entry.tags)
                .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)

            TimerLabelView(text: durationString, fontSize: 14, width: 90, alignment: .center)

            Text(statusText)
                .foregroundColor(statusColor)
                .fontWeight(.medium)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}
