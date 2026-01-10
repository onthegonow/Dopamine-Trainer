import SwiftUI
import CloudKit

struct HistoryView: View {

    enum Page {
        case activeTimers
        case history
    }

    @ObservedObject private var store = UrgeStore.shared
    @ObservedObject private var flags = FeatureFlags.shared
    @State private var showSummary = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Summary Dashboard (collapsible)
                if showSummary {
                    summaryContent()
                        .transition(.move(edge: .top).combined(with: .opacity))

                    Divider()
                        .padding(.vertical, 8)
                }

                // Toggle button for summary
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSummary.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showSummary ? "chevron.up" : "chevron.down")
                            Text(showSummary ? "Hide Summary" : "Show Summary")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                HistoryFilterStatusControl(selectedFilter: $store.currentFilter)
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                HistoryTableHeader()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                LazyVStack(spacing: 0) {
                    ForEach(store.historyEntriesPage) { entry in
                        HistoryRow(entry: entry)
                            .onAppear {
                                store.loadMoreHistoryIfNeeded(currentItem: entry)
                            }
                        Divider()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .toolbar {
            if flags.isAdmin {
                ToolbarItemGroup(placement: .automatic) {
                    Button("Clear Local History") {
                        clearLocalHistory()
                    }
                    Button("Clear Cloud History") {
                        Task { await clearCloudHistory() }
                    }
                }
            }
        }
        .onChange(of: store.currentFilter) {
            store.queryHistory(reset: true)
        }
        .onAppear {
            flags.setAdminFromCurrentCloudUser()
        }
    }

    @ViewBuilder
    private func summaryContent() -> some View {
        CravingSummaryDashboard(store: store)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private func clearLocalHistory() {
        let count = UrgeStore.shared.allHistoryEntriesForSummary.count
        UrgeStore.shared.replaceHistoryFromCloud([])
        // Reset the incremental CloudKit cursor so older events can be fetched again
        UserDefaults.standard.removeObject(forKey: "cloudLastSyncDate")
        print("[Admin] 🧹 Cleared local history: \(count) entries; reset cloudLastSyncDate")
        // Kick off a fresh merge to pull any remaining remote events (if any)
        UrgeStore.shared.pollCloudAndMerge(limit: 200)
    }

    private func clearCloudHistory() async {
        do {
            let events = try await CloudKitPublicSyncService.shared.fetchCravingHistory(limit: 1000)
            let count = events.count
            guard count > 0 else {
                print("[Admin] 🧹 Cleared cloud history: 0 entries (nothing to delete)")
                return
            }
            let recordIDs = events.map { CKRecord.ID(recordName: "craving_\($0.eventID)") }
            try await CloudKitPublicSyncService.shared.deleteCravingEvents(recordIDs: recordIDs)
            print("[Admin] 🧹 Cleared cloud history: \(count) entries")
        } catch {
            print("[Admin] ❌ error clearing cloud history: \(error)")
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

