import SwiftUI
import SwiftData
import PhotosUI
import GameMath
import DataSources
import ScreenshotImport

/// One Pokémon found in a batch of screenshots.
struct ScreenshotGroup: Identifiable {
    let id: Int
    /// 1-based positions of its screenshots in the picked batch.
    let screenshotNumbers: [Int]
    /// Nil when nothing usable (no CP) was read.
    let proposal: ScreenshotImporter.Proposal?
}

/// Add Pokémon from screenshots: one Pokémon or many at once. Everything runs on the phone.
struct ScreenshotImportView: View {
    @Environment(DataCenter.self) private var dataCenter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [CollectedPokemon]
    @State private var items: [PhotosPickerItem] = []
    @State private var progress: (done: Int, total: Int)?
    @State private var errorText: String?
    @State private var groups: [ScreenshotGroup] = []
    @State private var savedMessage: String?

    private let maxScreenshots = 40

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $items, maxSelectionCount: maxScreenshots, matching: .images) {
                    Label(items.isEmpty ? "Choose screenshots" : "Choose other screenshots", systemImage: "photo.on.rectangle")
                }
            } footer: {
                Text("Per Pokémon: the top of its screen, scrolled down to the power-up cost and moves, and its appraisal with the three bars. Pick up to \(maxScreenshots) screenshots, one or more Pokémon, keeping each Pokémon's screenshots together. The game must be in English.")
            }

            if let progress {
                Section {
                    HStack {
                        ProgressView()
                        Text("Reading screenshot \(min(progress.done + 1, progress.total)) of \(progress.total)…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let errorText {
                Section { Text(errorText).foregroundStyle(.secondary) }
            } else if !groups.isEmpty {
                summarySection
                Section(groups.count == 1 ? "Found 1 Pokémon" : "Found \(groups.count) Pokémon") {
                    ForEach(groups) { group in
                        if let proposal = group.proposal {
                            NavigationLink {
                                ScreenshotReviewView(proposal: proposal)
                            } label: {
                                GroupRow(group: group, proposal: proposal, isSaved: isInCollection(proposal),
                                         lookup: dataCenter.lookup)
                            }
                        } else {
                            UnreadGroupRow(group: group)
                        }
                    }
                }
            }
        }
        .navigationTitle("From screenshots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onChange(of: items) {
            Task { await scan() }
        }
    }

    // MARK: - Summary and bulk save

    private var readyToSave: [ScreenshotImporter.Proposal.CertainChoice] {
        groups.compactMap { group in
            guard let p = group.proposal, let choice = p.certainChoice, !isInCollection(p) else { return nil }
            return choice
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        let ready = readyToSave
        let unsure = groups.filter { g in g.proposal.map { $0.certainChoice == nil && !isInCollection($0) } ?? true }.count
        Section {
            if !ready.isEmpty {
                Button {
                    saveCertain()
                } label: {
                    Label(ready.count == 1 ? "Save the 1 sure Pokémon" : "Save the \(ready.count) sure Pokémon",
                          systemImage: "tray.and.arrow.down")
                }
            }
            if let savedMessage {
                Label(savedMessage, systemImage: "checkmark.circle").foregroundStyle(.green)
            }
        } footer: {
            if unsure > 0 {
                Text("\(unsure) need a choice from you (several levels or IVs fit, or something wasn't read). Tap them to review. Shiny isn't saved by \"Save\": set it in the review if needed.")
            } else {
                Text("Shiny can't be read from screenshots. To mark one as shiny, tap it and use the review instead.")
            }
        }
    }

    private func saveCertain() {
        guard let lookup = dataCenter.lookup else { return }
        var count = 0
        for group in groups {
            guard let p = group.proposal, let choice = p.certainChoice, !isInCollection(p) else { continue }
            let draft = p.draft(option: choice.option, solution: choice.solution, isShiny: false, lookup: lookup)
            if let model = draft.apply(to: nil) {
                modelContext.insert(model)
                count += 1
            }
        }
        try? modelContext.save()
        savedMessage = count == 1 ? "Saved 1 Pokémon." : "Saved \(count) Pokémon."
    }

    /// True when a collection entry matches one of the proposal's answers (same species, IVs, level, shadow).
    private func isInCollection(_ p: ScreenshotImporter.Proposal) -> Bool {
        let keys = Set(existing.map { CollectionImportView.key($0) })
        return p.options.contains { option in
            option.solutions.contains { s in
                keys.contains("\(option.pokemon.speciesId)|\(s.ivs.attack)|\(s.ivs.defense)|\(s.ivs.stamina)|\(s.level.halfSteps)|\(p.isShadow)")
            }
        }
    }

    // MARK: - Reading

    private func scan() async {
        guard !items.isEmpty else { return }
        errorText = nil
        groups = []
        savedMessage = nil
        progress = (0, items.count)
        defer { progress = nil }

        var scans: [ScreenshotScan] = []
        for (index, item) in items.enumerated() {
            progress = (index, items.count)
            if let data = try? await item.loadTransferable(type: Data.self),
               let scan = try? await Task.detached(priority: .userInitiated, operation: { try ScreenshotReader.scan(data) }).value {
                scans.append(scan)
            } else {
                scans.append(ScreenshotScan(reading: ScreenReading(), barFractions: [:]))
            }
        }
        guard let gm = dataCenter.gamemaster, let lookup = dataCenter.lookup, let tables = PlannerMath.tables else {
            errorText = "Pokémon data is still loading. Try again in a moment."
            return
        }
        let finalScans = scans
        groups = await Task.detached(priority: .userInitiated) { () -> [ScreenshotGroup] in
            ScreenshotGrouping.group(finalScans.map(\.reading)).enumerated().map { number, indices in
                var reading = ScreenReading()
                var bars: [AppraisalStat: Double] = [:]
                for i in indices {
                    reading = reading.merged(with: finalScans[i].reading)
                    for (stat, value) in finalScans[i].barFractions where bars[stat] == nil { bars[stat] = value }
                }
                let proposal = ScreenshotImporter.propose(reading, barFractions: bars, gamemaster: gm, lookup: lookup, tables: tables)
                return ScreenshotGroup(id: number, screenshotNumbers: indices.map { $0 + 1 }, proposal: proposal)
            }
        }.value
    }
}

// MARK: - Rows

private struct GroupRow: View {
    let group: ScreenshotGroup
    let proposal: ScreenshotImporter.Proposal
    let isSaved: Bool
    let lookup: GamemasterLookup?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.headline)
                if proposal.isLucky { Image(systemName: "star.circle").foregroundStyle(.yellow).accessibilityLabel("Lucky") }
                if proposal.isShadow { Image(systemName: "flame.fill").foregroundStyle(.purple).accessibilityLabel("Shadow") }
                Spacer()
                status
            }
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        if let choice = proposal.certainChoice { return choice.option.pokemon.speciesName }
        if proposal.options.count == 1 { return proposal.options[0].pokemon.speciesName }
        return proposal.reading.name ?? "Unknown Pokémon"
    }

    private var detail: String {
        var parts: [String] = []
        if let s = proposal.certainChoice?.solution {
            parts.append(PokemonStats.line(cp: proposal.reading.cp, level: s.level, ivs: s.ivs))
        } else if let cp = proposal.reading.cp {
            parts.append("CP \(cp)")
        }
        if proposal.certainChoice != nil {
            // Nothing to add: the stats line says it all.
        } else if proposal.options.isEmpty {
            parts.append("nothing fits")
        } else if proposal.options.count > 1 {
            parts.append("\(proposal.options.count) Pokémon fit")
        } else {
            parts.append("\(proposal.options[0].solutions.count) level/IV options")
        }
        parts.append(group.screenshotNumbers.count == 1 ? "screenshot \(group.screenshotNumbers[0])"
                     : "screenshots \(group.screenshotNumbers.map(String.init).joined(separator: ", "))")
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var status: some View {
        if isSaved {
            Label("Saved", systemImage: "checkmark.circle.fill").labelStyle(.iconOnly).foregroundStyle(.green)
                .accessibilityLabel("In your collection")
        } else if proposal.certainChoice != nil {
            Text("Sure").font(.caption2).foregroundStyle(.secondary)
        } else {
            Image(systemName: "questionmark.circle").foregroundStyle(.orange).accessibilityLabel("Needs a choice")
        }
    }
}

private struct UnreadGroupRow: View {
    let group: ScreenshotGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Couldn't read a CP", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            Text("Screenshot \(group.screenshotNumbers.map(String.init).joined(separator: ", ")). Include the top of the Pokémon's screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Draft

extension ScreenshotImporter.Proposal {
    /// The editor's draft for one answer: species, level, IVs, moves read from the screen, flags.
    func draft(option: ScreenshotImporter.SpeciesOption, solution: IVSolver.Solution, isShiny: Bool,
               lookup: GamemasterLookup) -> CollectionDraft {
        var d = CollectionDraft()
        d.select(option.pokemon, lookup: lookup)
        d.ivs = solution.ivs
        d.level = solution.level
        let read = self.moves(for: option.pokemon, lookup: lookup)
        d.fastMoveId = read.fast ?? ""
        d.chargedMoveId = read.charged.first ?? ""
        d.secondChargedMoveId = read.charged.count > 1 ? read.charged[1] : ""
        d.isShadow = isShadow
        d.isLucky = isLucky && !isShadow
        d.isShiny = isShiny
        return d
    }
}
