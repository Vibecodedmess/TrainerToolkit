import SwiftUI
import SwiftData
import GameMath

/// Trade Planner: friends, their want lists and the estimated stardust cost per trade.
struct TradesView: View {
    @Query(sort: \TradeFriend.createdAt) private var friends: [TradeFriend]
    @Environment(\.modelContext) private var modelContext
    @Environment(DataCenter.self) private var dataCenter
    @State private var showingAdd = false
    @State private var pendingDelete: TradeFriend?

    private var sortedFriends: [TradeFriend] {
        friends.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            Section("Friends") {
                if friends.isEmpty {
                    ContentUnavailableView {
                        Label("No friends yet", systemImage: "person.2")
                    } description: {
                        Text("Add the trainers you trade with, their friendship level and what each of you wants.")
                    } actions: {
                        Button("Add friend") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ForEach(sortedFriends) { friend in
                        NavigationLink {
                            FriendDetailView(friend: friend)
                        } label: {
                            FriendRow(friend: friend, tables: TradeData.tables)
                        }
                        .swipeActions {
                            // Not role: .destructive, so the row doesn't vanish before the confirmation.
                            Button {
                                pendingDelete = friend
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDelete = friend
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            Section {
                NavigationLink { BaseTradeCostsView() } label: {
                    Label("Base trade costs", systemImage: "sparkles")
                }
                NavigationLink { FriendshipLevelsView() } label: {
                    Label("Friendship levels", systemImage: "heart.text.square")
                }
                NavigationLink { TradeCalculationNoteView() } label: {
                    Label("How this is calculated", systemImage: "info.circle")
                }
            } header: {
                Text("Trade data")
            }
        }
        .navigationTitle("Trades")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add friend", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                FriendEditorView(friend: nil)
            }
            .environment(dataCenter)
            .modelContext(modelContext)
        }
        .confirmationDialog(
            "Delete this friend?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { friend in
            Button("Delete \(friend.name)", role: .destructive) { delete(friend) }
        } message: { _ in
            Text("Their want lists are deleted too.")
        }
    }

    private func delete(_ friend: TradeFriend) {
        modelContext.delete(friend)
        try? modelContext.save()
        pendingDelete = nil
    }
}

private struct FriendRow: View {
    let friend: TradeFriend
    let tables: TradeTables?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(friend.name)
                    .font(.headline)
                    .lineLimit(1)
                if friend.isLuckyFriend {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Lucky friend")
                }
            }
            Text(levelLine)
                .font(.subheadline)
            if !wantsLine.isEmpty {
                Text(wantsLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var levelLine: String {
        var parts = [TradeFormat.levelTitle(friend.friendshipLevel)]
        if let discount = tables?.discount(atLevel: friend.friendshipLevel), discount > 0 {
            parts.append("\(TradeFormat.percent(discount)) trade discount")
        }
        if let date = friend.nextLevelDate {
            parts.append("next level \(date.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.joined(separator: " · ")
    }

    private var wantsLine: String {
        let open = friend.wants.filter { !$0.isDone }
        let theirs = open.filter(\.theyWant).count
        let mine = open.count - theirs
        var parts: [String] = []
        if theirs > 0 { parts.append("\(theirs) they want") }
        if mine > 0 { parts.append("\(mine) I want") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { TradesView() }
        .environment(DataCenter())
        .modelContainer(for: [TradeFriend.self, TradeWant.self], inMemory: true)
}
