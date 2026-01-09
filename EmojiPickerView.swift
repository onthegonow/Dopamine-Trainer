import SwiftUI

struct EmojiPickerSheet: View {
    var onSelect: (String, String) -> Void
    var onCancel: () -> Void

    @State private var selectedEmoji: String?
    @State private var label: String = ""

    private let columns = [GridItem(.adaptive(minimum: 36), spacing: 8)]
    private let emojis = EmojiPickerData.commonEmojis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a new urge tag")
                .font(.headline)

            HStack(spacing: 12) {
                Text(selectedEmoji ?? "🙂")
                    .font(.system(size: 32))
                    .frame(width: 44, height: 44)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                TextField("Tag description (tooltip)", text: $label)
                    .textFieldStyle(.roundedBorder)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(emojis, id: \.self) { e in
                        Button {
                            selectedEmoji = e
                        } label: {
                            Text(e)
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedEmoji == e ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 220)

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Add") {
                    if let e = selectedEmoji, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSelect(e, label.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .disabled(selectedEmoji == nil || label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420, height: 380)
    }
}

enum EmojiPickerData {
    static let commonEmojis: [String] = [
        // Smileys & Emotion
        "😀","😃","😄","😁","😆","😊","🙂","😉","😍","😘","😗","😙","😚","😋","😛","😜","🤪","🤨","🫠","😐","😑","😶","🙄","😮‍💨","😴","🤤","😪","😵","🤯","🤕","🤒","🥴","🥵","🥶","😡","😠","🤬","😢","😭","😱","😨","😰","😥","😓","😶‍🌫️","😬","🤥","🤫","🤭","🫢","🫣","😈","👿","💀","☠️",
        // People & Hand
        "👍","👎","👊","✊","🤛","🤜","👏","🙌","👐","🤲","🙏","🤝","✌️","🤘","👌","🤌","🤏","👆","👇","👉","👈","✍️","💪","🖖","🤟","🫶",
        // Activities & Objects
        "🎮","🎲","🎯","🎳","🎰","🏓","🏸","⛳️","🎣","🎹","🥁","🎸","🎺","🎻","🎤",
        // Food & Drink
        "🍎","🍊","🍌","🍉","🍇","🍓","🍒","🍑","🍍","🥭","🍐","🍋","🍈","🥝","🍅","🥕","🌽","🥔","🍞","🥐","🥖","🥨","🧀","🍗","🍖","🍔","🍟","🍕","🌭","🥪","🌮","🌯","🥙","🥗","🍣","🍱","🍜","🍝","🍲","🍥","🥠","🍰","🧁","🍩","🍪","🍫","🍬","🍭","🍮","🍯",
        // Symbols & Misc
        "🚬","🔞","🌐","🏷️","💡","🔥","✨","⭐️","⚡️","💧","🌊","🌙","☀️","🌈","❗️","❓","✅","❌","🔔","🔕","🔒","🔓","🔑","🧭","🧠","🧪","🧰","🪫","🔋"
    ]
}
