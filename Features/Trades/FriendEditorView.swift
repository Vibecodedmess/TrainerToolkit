import SwiftUI
import SwiftData
import GameMath

/// Add or edit a trade friend. Shown in a sheet with Cancel and Save.
struct FriendEditorView: View {
    /// nil = new friend.
    let friend: TradeFriend?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var level: Int
    @State private var isLucky: Bool
    @State private var notes: String
    @State private var hasNextLevelDate: Bool
    @State private var nextLevelDate: Date
    @FocusState private var keyboardFocused: Bool

    init(friend: TradeFriend?) {
        self.friend = friend
        _name = State(initialValue: friend?.name ?? "")
        _level = State(initialValue: friend?.friendshipLevel ?? 0)
        _isLucky = State(initialValue: friend?.isLuckyFriend ?? false)
        _notes = State(initialValue: friend?.notes ?? "")
        _hasNextLevelDate = State(initialValue: friend?.nextLevelDate != nil)
        _nextLevelDate = State(initialValue: friend?.nextLevelDate ?? .now)
    }

    private var tables: TradeTables? { TradeData.tables }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section("Friend") {
                TextField("Name (required)", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($keyboardFocused)
            }
            friendshipSection
            Section {
                Toggle("Next level date", isOn: $hasNextLevelDate)
                if hasNextLevelDate {
                    DatePicker("Reached on", selection: $nextLevelDate, displayedComponents: .date)
                }
            } footer: {
                Text("The day you reach the next friendship level, if you know it.")
            }
            Section("Notes") {
                TextField("Optional", text: $notes, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($keyboardFocused)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(friend == nil ? "Add friend" : "Edit friend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(trimmedName.isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { keyboardFocused = false }
            }
        }
    }

    @ViewBuilder
    private var friendshipSection: some View {
        Section {
            if let tables {
                Picker("Friendship level", selection: $level) {
                    ForEach(tables.friendshipLevels) { option in
                        Text(TradeFormat.pickerLabel(option)).tag(option.level)
                    }
                    // Keep a saved level selectable even if the data no longer lists it.
                    if tables.level(level) == nil {
                        Text("\(TradeFormat.levelTitle(level)) (saved)").tag(level)
                    }
                }
            } else {
                LabeledContent("Friendship level", value: TradeFormat.levelTitle(level))
            }
            Toggle("Lucky friend", isOn: $isLucky)
        } header: {
            Text("Friendship")
        } footer: {
            if let tables, let info = tables.level(level) {
                Text(levelSummary(info))
            } else if tables == nil {
                Text("The bundled trade data could not be loaded.")
            }
        }
    }

    private func levelSummary(_ info: TradeTables.FriendshipLevel) -> String {
        var parts: [String] = []
        if let discount = info.tradingDiscount, discount > 0 {
            parts.append("Trade discount \(TradeFormat.percent(discount)).")
        } else {
            parts.append("No trade discount in the data.")
        }
        parts.append("\(info.unlockedTrading.count) trade types unlocked.")
        parts.append("Level names aren't in the data, so levels are numbered as in the game master.")
        return parts.joined(separator: " ")
    }

    private func save() {
        let target = friend ?? TradeFriend(name: trimmedName)
        target.name = trimmedName
        target.friendshipLevel = level
        target.isLuckyFriend = isLucky
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.nextLevelDate = hasNextLevelDate ? nextLevelDate : nil
        if friend == nil { modelContext.insert(target) }
        try? modelContext.save()
        dismiss()
    }
}
