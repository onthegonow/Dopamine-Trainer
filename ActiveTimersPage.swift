import SwiftUI

struct ActiveTimersPage: View {

    @ObservedObject private var store = UrgeStore.shared
    @ObservedObject private var timerEngine = UrgeTimerEngine.shared

    @State private var deleteConfirmationEntry: UrgeEntryModel?
    @State private var selection: HistoryView.Page = .activeTimers

    var body: some View {
        VStack(spacing: 0) {
            // Top navigation picker - explicitly NOT a toolbar
            VStack {
                Picker("View", selection: $selection) {
                    Text("Active Timers").tag(HistoryView.Page.activeTimers)
                    Text("History").tag(HistoryView.Page.history)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))

            if selection == .activeTimers {
                VStack(spacing: 0) {
                    // Button at the top - NOT in the scrollable area
                    CravingButton {
                        store.createActive()
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    
                    // List below - this is the scrollable area
                    if store.activeEntries.isEmpty {
                        Spacer()
                        Text("No active urges")
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            List {
                                ForEach(store.activeEntries) { entry in
                                    ActiveTimerRow(entry: entry,
                                                   timerEngine: timerEngine,
                                                   onBeatIt: { store.resolve(entryId: entry.id, status: .beatIt) },
                                                   onScratchedItch: { store.resolve(entryId: entry.id, status: .satisfied) })
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            deleteConfirmationEntry = entry
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                    .id(entry.id) // Add ID so we can scroll to it
                                }
                            }
                            .listStyle(PlainListStyle())
                            .onChange(of: store.activeEntries.map { $0.id }) { oldIDs, newIDs in
                                // When the list of IDs changes, scroll to the first entry
                                if let firstEntry = store.activeEntries.first {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo(firstEntry.id, anchor: .top)
                                    }
                                }
                            }
                        }
                    }
                }
            } else if selection == .history {
                HistoryView()
            }
        }
        .alert(item: $deleteConfirmationEntry) { entry in
            Alert(title: Text("Delete Active Urge?"),
                  message: Text("Are you sure you want to cancel this active urge? This cannot be undone."),
                  primaryButton: .destructive(Text("Delete")) {
                    store.delete(entryId: entry.id)
                  },
                  secondaryButton: .cancel())
        }
        .frame(minWidth: 800, minHeight: 400)
        .toolbarRole(.editor)
        .onAppear {
            AutoFadeReconciler(store: store).start()
        }
    }
}

struct CravingButton: View {
    let action: () -> Void
    
    @State private var isPressed = false
    
    private let buttonSize: CGFloat = 140
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.95, green: 0.5, blue: 0.15), Color(red: 0.85, green: 0.45, blue: 0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: buttonSize / 2
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(color: Color(red: 0.85, green: 0.45, blue: 0.1).opacity(0.5), radius: isPressed ? 5 : 15, x: 0, y: isPressed ? 2 : 8)
                
                Text("Dopamine\nCraving")
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct ActiveTimerRow: View {
    let entry: UrgeEntryModel
    @ObservedObject var timerEngine: UrgeTimerEngine
    let onBeatIt: () -> Void
    let onScratchedItch: () -> Void

    @State private var showingAddTag: Bool = false

    private var elapsedTimeString: String {
        let duration = entry.durationSeconds
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                TimerLabelView(text: elapsedTimeString, fontSize: 36, width: 200, alignment: .leading)
                    .padding(.top, 4) // Align with top of tags

                InlineTagToggles(entryId: entry.id, selectedTags: entry.tags) {
                    showingAddTag = true
                }
                .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading) // Increased from 180 to 240

                Spacer(minLength: 20) // Add space before buttons

                Button("Beat it!") {
                    onBeatIt()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.76, green: 0.94, blue: 0.78))
                .controlSize(.large)
                .font(.title3)
                .frame(minWidth: 140)

                Button("Scratched the itch") {
                    onScratchedItch()
                }
                .buttonStyle(.bordered)
                .tint(Color(red: 1.0, green: 0.8, blue: 0.8))
                .controlSize(.large)
                .font(.title3)
            }
        }
        .padding(.vertical, 12)
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

