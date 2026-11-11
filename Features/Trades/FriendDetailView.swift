import SwiftUI
import SwiftData
import GameMath
import DataSources

/// One friend: friendship info, cost check, both want lists and the trade types their level unlocks.
struct FriendDetailView: View {
    enum WantSide: String, Identifiable {
        case theirs, mine
        var id: String { rawValue }
        var theyWant: Bool { self == .theirs }
        var title: String { self == .theirs ? "They want" : "I want" }
    }

    let friend: TradeFriend

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(DataCenter.self) private var dataCenter
    @State private var editing = false
    @State private var addingTo: WantSide?
    @State private var confirmDelete = false
    @AppStorage("trades.costCheck.kind") private var kindRaw = TradeKind.regularRegistered.rawValue
    private var baseCosts: BaseTradeCosts

    init(friend: TradeFriend) {
        self.friend = friend
        baseCosts = BaseTradeCosts()
    }

    private var tables: TradeTables? { TradeData.tables }
    private var kind: TradeKind { TradeKind(rawValue: kindRaw) ?? .regularRegistered }
    private var levelInfo: TradeTables.FriendshipLevel? { tables?.level(friend.friendshipLevel) }

    var body: some View {
        List {
            infoSection
            costSection
            wantSection(.theirs)
            wantSection(.mine)
            unlocksSection
            Section {
                Button("Delete friend", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(friend.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack {
                FriendEditorView(friend: friend)
            }
            .environment(dataCenter)
            .modelContext(modelContext)
        }
        .sheet(item: $addingTo) { side in
            NavigationStack {
                WantEditorView(friend: friend, want: nil, theyWant: side.theyWant)
            }
            .environment(dataCenter)
            .modelContext(modelContext)
        }
        .confirmationDialog("Delete \(friend.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteFriend)
        } message: {
            Text("Their want lists are deleted too.")
        }
    }

    // MARK: - Sections

    private var infoSection: some View {
        Section {
            LabeledContent("Friendship level", value: TradeFormat.levelTitle(friend.friendshipLevel))
            if let info = levelInfo, let points = TradeFormat.pointsText(info) {
                LabeledContent("Reached", value: points)
            }
            if friend.isLuckyFriend {
                Label("Lucky friend", systemImage: "star.fill")
            }
            if let date = friend.nextLevelDate {
                LabeledContent("Next level", value: date.formatted(date: .abbreviated, time: .omitted))
            }
            if !friend.notes.isEmpty {
                Text(friend.notes)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var costSection: some View {
        Section {
            Picker("Trade type", selection: $kindRaw) {
                ForEach(TradeKind.allCases) { Text($0.title).tag($0.rawValue) }
            }
            if let tables {
                let level = friend.friendshipLevel
                let discount = tables.discount(atLevel: level)
                LabeledContent("Discount at \(TradeFormat.levelTitle(level).lowercased())",
                               value: discount > 0 ? TradeFormat.percent(discount) : "None in the data")
                if let base = baseCosts.base(for: kind), let cost = tables.cost(base: base, friendshipLevel: level) {
                    LabeledContent("Base cost", value: TradeFormat.stardust(base))
                    LabeledContent("Estimated cost") {
                        Text(TradeFormat.stardust(cost))
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                } else {
                    NavigationLink {
                        BaseTradeCostsView()
                    } label: {
                        LabeledContent("Estimated cost", value: "Enter base costs")
                    }
                }
                if let categoryId = kind.unlockCategoryId {
                    if tables.isUnlocked(categoryId, atLevel: level) {
                        Label("Unlocked at this level", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not unlocked at this level", systemImage: "xmark.circle")
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Text("The bundled trade data could not be loaded.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Cost check")
        } footer: {
            Text("Estimate = your base cost × (1 − the discount from the game master). Check the trade screen in the game before trading.")
        }
    }

    private func entries(_ side: WantSide) -> [TradeWant] {
        friend.wants
            .filter { $0.theyWant == side.theyWant }
            .sorted { lhs, rhs in
                if lhs.isDone != rhs.isDone { return !lhs.isDone }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private func wantSection(_ side: WantSide) -> some View {
        let list = entries(side)
        return Section {
            if list.isEmpty {
                Text("Nothing on this list yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(list) { want in
                WantRow(friend: friend, want: want, lookupTypes: types(for: want)) {
                    want.isDone.toggle()
                    try? modelContext.save()
                }
            }
            .onDelete { offsets in
                deleteWants(offsets.map { list[$0] })
            }
            Button {
                addingTo = side
            } label: {
                Label("Add to \"\(side.title)\"", systemImage: "plus")
            }
        } header: {
            Text(side.title)
        }
    }

    @ViewBuilder
    private var unlocksSection: some View {
        if let info = levelInfo {
            Section {
                ForEach(info.unlockedTrading, id: \.self) { id in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TradeTables.readableCategory(id))
                        Text(id)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Trade types unlocked at \(TradeFormat.levelTitle(info.level).lowercased())")
            } footer: {
                Text("From the game master's unlockedTrading list. \"Registered\" = already in the Pokédex.")
            }
        }
    }

    // MARK: - Actions

    private func types(for want: TradeWant) -> [String] {
        guard !want.speciesId.isEmpty else { return [] }
        return dataCenter.lookup?.pokemon(id: want.speciesId)?.realTypes ?? []
    }

    private func deleteWants(_ wants: [TradeWant]) {
        let ids = Set(wants.map(\.persistentModelID))
        friend.wants.removeAll { ids.contains($0.persistentModelID) }
        for want in wants { modelContext.delete(want) }
        try? modelContext.save()
    }

    private func deleteFriend() {
        let target = friend
        let context = modelContext
        dismiss()
        // Delete after the screen has closed, so it never draws a deleted friend.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            context.delete(target)
            try? context.save()
        }
    }
}

/// One want-list row: a done toggle, the species (or note) and its type badges. Tap to edit.
private struct WantRow: View {
    let friend: TradeFriend
    let want: TradeWant
    let lookupTypes: [String]
    let toggleDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleDone) {
                Image(systemName: want.isDone ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(want.isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(want.isDone ? "Done. Mark as not done" : "Mark as done")

            NavigationLink {
                WantEditorView(friend: friend, want: want, theyWant: want.theyWant)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(want.title)
                                .strikethrough(want.isDone)
                                .foregroundStyle(want.isDone ? HierarchicalShapeStyle.secondary : .primary)
                            if want.isShiny {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                                    .accessibilityLabel("Shiny")
                            }
                        }
                        if !want.speciesName.isEmpty && !want.note.isEmpty {
                            Text(want.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    TypeBadges(types: lookupTypes)
                }
            }
        }
    }
}
