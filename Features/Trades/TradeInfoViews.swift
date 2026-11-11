import SwiftUI
import GameMath

/// The user's base stardust cost per trade kind. These are not in any data source.
struct BaseTradeCostsView: View {
    private var baseCosts: BaseTradeCosts
    @State private var confirmClear = false
    @FocusState private var keyboardFocused: Bool

    init() {
        baseCosts = BaseTradeCosts()
    }

    var body: some View {
        Form {
            Section {
                ForEach(TradeKind.allCases) { kind in
                    LabeledContent(kind.title) {
                        ZeroIntField(title: "Stardust", value: baseCosts.binding(for: kind))
                            .focused($keyboardFocused)
                    }
                }
            } header: {
                Text("Stardust per trade, before discount")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Copy these from the trade screen in the game.")
                    if let tables = TradeData.tables {
                        let levels = TradeFormat.levelsWithoutDiscount(tables)
                        if !levels.isEmpty {
                            Text("The full price shows with a friend at a level without a trade discount (in the data: level \(levels)).")
                        }
                    }
                    Text("\"Registered\" = already in the Pokédex. Leave a box empty if you don't know the cost; the planner then shows \"Enter base costs\".")
                }
            }
            Section {
                Button("Clear all", role: .destructive) { confirmClear = true }
                    .disabled(baseCosts.isEmpty)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Base trade costs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { keyboardFocused = false }
            }
        }
        .confirmationDialog("Clear all base costs?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear all", role: .destructive) { baseCosts.clear() }
        }
    }
}

/// Everything the bundled data says about each friendship level, plus the remote trade settings.
struct FriendshipLevelsView: View {
    private var tables: TradeTables? { TradeData.tables }

    var body: some View {
        List {
            if let tables {
                ForEach(tables.friendshipLevels) { level in
                    Section {
                        levelRows(level)
                    } header: {
                        Text(TradeFormat.levelTitle(level.level))
                    }
                }
                if let remote = tables.remoteTrade {
                    remoteSection(remote)
                }
                Section {
                    Text("From the PokeMiners game master, templates FRIENDSHIP_LEVEL_* and REMOTE_TRADE_SETTINGS, commit \(String(tables.source.commit.prefix(7))) (extracted \(tables.source.extracted)).")
                    Text("Level names aren't in the data, so levels are numbered. Values are shown as the data gives them, also where two levels share a number.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView("Trade data missing", systemImage: "exclamationmark.triangle",
                                       description: Text("The bundled trade data could not be loaded."))
            }
        }
        .navigationTitle("Friendship levels")
    }

    @ViewBuilder
    private func levelRows(_ level: TradeTables.FriendshipLevel) -> some View {
        LabeledContent("Points to reach", value: level.minPointsToReach.map { "\($0)" } ?? "Not in the data")
        if let relative = level.relativePointsToReach {
            LabeledContent("Relative points to reach", value: "\(relative)")
        }
        LabeledContent("Trade discount", value: level.tradingDiscount.map(TradeFormat.percent) ?? "None")
        if let attack = level.attackBonusPercentage {
            LabeledContent("Attack bonus", value: TradeFormat.multiplier(attack))
        }
        if let balls = level.raidBallBonus {
            LabeledContent("Raid ball bonus", value: "+\(balls)")
        }
        if let xp = level.milestoneXpReward {
            LabeledContent("Milestone XP", value: xp.formatted())
        }
        LabeledContent("Lucky friend item usable", value: level.unlockedLuckyFriendApplicator ? "Yes" : "No")
        DisclosureGroup("\(level.unlockedTrading.count) trade types unlocked") {
            ForEach(level.unlockedTrading, id: \.self) { id in
                Text(TradeTables.readableCategory(id))
            }
        }
    }

    private func remoteSection(_ remote: TradeTables.RemoteTradeSettings) -> some View {
        Section {
            if let enabled = remote.enabled {
                LabeledContent("Enabled", value: enabled ? "Yes" : "No")
            }
            numberRow("Remote trades per day", remote.maxRemoteTradesPerDay)
            numberRow("Pokémon per trade request", remote.requestedPokemonCount)
            numberRow("Untradable days", remote.pokemonUntradableDays)
            numberRow("Tagging unlock point threshold", remote.taggingUnlockPointThreshold)
            numberRow("Time limit (minutes)", remote.timeLimitMinutes)
            numberRow("Expiry reminder (minutes)", remote.tradeExpiryReminderMinutes)
        } header: {
            Text("Remote trades")
        } footer: {
            Text("REMOTE_TRADE_SETTINGS as the game master gives it. The labels are read from the setting names.")
        }
    }

    @ViewBuilder
    private func numberRow(_ title: String, _ value: Int?) -> some View {
        if let value {
            LabeledContent(title, value: value.formatted())
        }
    }
}

/// "How this is calculated" for the Trade Planner.
struct TradeCalculationNoteView: View {
    var body: some View {
        List {
            Section("Estimated cost") {
                Text("Estimated stardust = your base cost × (1 − trading discount), rounded to the nearest whole number.")
                Text("The game's own rounding isn't confirmed, so check the trade screen before trading.")
                    .foregroundStyle(.secondary)
            }
            Section("Trading discount and unlocked trade types") {
                if let tables = TradeData.tables {
                    Text("From the PokeMiners game master (a community datamine of the game's public game master), templates FRIENDSHIP_LEVEL_* (tradingDiscount, unlockedTrading).")
                    LabeledContent("Commit", value: String(tables.source.commit.prefix(7)))
                    LabeledContent("Extracted", value: tables.source.extracted)
                    Text(tables.source.url)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("The bundled trade data could not be loaded.")
                }
            }
            Section("Base costs") {
                Text("The base stardust cost of a trade is not in the game master, and no official source was found. You enter it once under Base trade costs, copied from the trade screen in the game.")
            }
            Section("Friendship level") {
                Text("You set each friend's level. Level names aren't in the data, so levels are numbered as in the game master.")
            }
        }
        .navigationTitle("How this is calculated")
        .navigationBarTitleDisplayMode(.inline)
    }
}
