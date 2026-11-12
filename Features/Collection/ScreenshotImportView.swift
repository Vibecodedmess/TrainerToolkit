import SwiftUI
import PhotosUI
import GameMath
import DataSources
import ScreenshotImport

/// Add a Pokémon from screenshots of its screen and appraisal. Everything runs on the phone.
struct ScreenshotImportView: View {
    @Environment(DataCenter.self) private var dataCenter
    @Environment(\.dismiss) private var dismiss
    @State private var items: [PhotosPickerItem] = []
    @State private var scanning = false
    @State private var errorText: String?
    @State private var proposal: ScreenshotImporter.Proposal?
    @State private var speciesId: String?
    @State private var solutionId: String?
    @State private var showAllSolutions = false
    /// The game's shiny mark can't be read reliably from a screenshot, so the user sets it here.
    @State private var isShiny = false

    private let maxScreenshots = 4

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $items, maxSelectionCount: maxScreenshots, matching: .images) {
                    Label(items.isEmpty ? "Choose screenshots" : "Choose other screenshots", systemImage: "photo.on.rectangle")
                }
            } footer: {
                Text("Pick up to \(maxScreenshots) screenshots of one Pokémon: its screen (the top, and scrolled down to the power-up cost and moves) and its appraisal with the three bars. The game must be in English.")
            }

            if scanning {
                Section { HStack { ProgressView(); Text("Reading screenshots…").foregroundStyle(.secondary) } }
            } else if let errorText {
                Section { Text(errorText).foregroundStyle(.secondary) }
            } else if let proposal {
                readSection(proposal)
                resultSections(proposal)
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

    // MARK: - Sections

    private func readSection(_ p: ScreenshotImporter.Proposal) -> some View {
        let r = p.reading
        return Section {
            LabeledContent("CP", value: r.cp.map(String.init) ?? "Not found")
            LabeledContent("HP", value: r.hp.map(String.init) ?? "Not found")
            LabeledContent("Name", value: r.name ?? "Not found")
            if let family = r.candyFamily { LabeledContent("Candy", value: family) }
            if !r.types.isEmpty { LabeledContent("Type") { TypeBadges(types: r.types) } }
            LabeledContent("Power-up stardust", value: r.powerUpStardust.map { $0.formatted() } ?? "Not found")
            LabeledContent("Appraisal IVs", value: barText(p.barIVs))
            if p.isShadow { Label("Shadow (PURIFY button found)", systemImage: "flame.fill") }
            if p.isLucky { Label("Lucky", systemImage: "star.circle") }
        } header: {
            Text("Read from the screenshots")
        } footer: {
            if p.ignoredStardust {
                Text("No level fits the power-up stardust that was read, so it was ignored. Check the level below.")
            }
        }
    }

    @ViewBuilder
    private func resultSections(_ p: ScreenshotImporter.Proposal) -> some View {
        if p.options.isEmpty {
            Section {
                Text(p.reading.cp == nil
                     ? "The CP couldn't be read. Use a screenshot of the top of the Pokémon's screen."
                     : "No Pokémon, level and IVs fit what was read. Check that the screenshots show one Pokémon, or add it by hand.")
                    .foregroundStyle(.secondary)
            }
        } else if let lookup = dataCenter.lookup {
            let option = p.options.first { $0.pokemon.speciesId == speciesId } ?? p.options[0]
            Section {
                if p.options.count > 1 {
                    Picker("Pokémon", selection: Binding(get: { option.pokemon.speciesId }, set: { speciesId = $0; solutionId = nil })) {
                        ForEach(p.options) { Text($0.pokemon.speciesName).tag($0.pokemon.speciesId) }
                    }
                } else {
                    LabeledContent("Pokémon", value: option.pokemon.speciesName)
                }
                let moves = p.moves(for: option.pokemon, lookup: lookup)
                LabeledContent("Moves", value: movesText(moves, lookup: lookup))
                Toggle(isOn: $isShiny) {
                    Label("Shiny", systemImage: "sparkles")
                }
            } header: {
                Text("Pokémon")
            } footer: {
                if p.options.count > 1 {
                    Text("More than one Pokémon fits (a nickname, or regional forms). Pick the right one. Shiny can't be read from screenshots, so set it here.")
                } else {
                    Text("Shiny can't be read from screenshots, so set it here.")
                }
            }
            solutionsSection(option, barsMissing: p.barIVs.isEmpty)
            Section {
                NavigationLink {
                    CollectionEditorView(prefilled: draft(p, option, lookup: lookup))
                } label: {
                    Label("Review and save", systemImage: "square.and.pencil")
                }
            } footer: {
                Text("Opens the normal editor with these values. Check them, then tap Save.")
            }
        }
    }

    private func solutionsSection(_ option: ScreenshotImporter.SpeciesOption, barsMissing: Bool) -> some View {
        let all = option.solutions
        let shown = showAllSolutions ? Array(all.prefix(60)) : Array(all.prefix(6))
        let selected = all.first { $0.id == solutionId } ?? all[0]
        return Section {
            ForEach(shown) { s in
                Button {
                    solutionId = s.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Level \(s.level.description) · \(s.ivs.attack)/\(s.ivs.defense)/\(s.ivs.stamina) (\(s.ivs.percent)%)")
                                .foregroundStyle(.primary)
                            if s.distance == 0 && !barsMissing {
                                Text("Matches the appraisal bars").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if s.id == selected.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
            }
            if all.count > shown.count {
                Button("Show all \(all.count) possibilities") { showAllSolutions = true }
            }
        } header: {
            Text(all.count == 1 ? "Level and IVs" : "Level and IVs (\(all.count) fit)")
        } footer: {
            if all.count > 1 {
                Text("Several combinations give this CP and HP. An appraisal screenshot narrows it down.")
            }
        }
    }

    // MARK: - Helpers

    private func barText(_ hints: IVSolver.Hints) -> String {
        guard !hints.isEmpty else { return "No appraisal found" }
        return [hints.attack, hints.defense, hints.stamina].map { $0.map(String.init) ?? "?" }.joined(separator: "/")
    }

    private func movesText(_ moves: (fast: String?, charged: [String]), lookup: GamemasterLookup) -> String {
        let names = ([moves.fast].compactMap { $0 } + moves.charged).map { lookup.moveName($0) }
        return names.isEmpty ? "Not found" : names.joined(separator: ", ")
    }

    private func draft(_ p: ScreenshotImporter.Proposal, _ option: ScreenshotImporter.SpeciesOption,
                       lookup: GamemasterLookup) -> CollectionDraft {
        let solution = option.solutions.first { $0.id == solutionId } ?? option.solutions[0]
        var d = CollectionDraft()
        d.select(option.pokemon, lookup: lookup)
        d.ivs = solution.ivs
        d.level = solution.level
        let moves = p.moves(for: option.pokemon, lookup: lookup)
        d.fastMoveId = moves.fast ?? ""
        d.chargedMoveId = moves.charged.first ?? ""
        d.secondChargedMoveId = moves.charged.count > 1 ? moves.charged[1] : ""
        d.isShadow = p.isShadow
        d.isLucky = p.isLucky && !p.isShadow
        d.isShiny = isShiny
        return d
    }

    private func scan() async {
        guard !items.isEmpty else { return }
        scanning = true
        errorText = nil
        proposal = nil
        speciesId = nil
        solutionId = nil
        showAllSolutions = false
        isShiny = false
        defer { scanning = false }

        var reading = ScreenReading()
        var bars: [AppraisalStat: Double] = [:]
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard let scan = try? await Task.detached(priority: .userInitiated, operation: { try ScreenshotReader.scan(data) }).value else { continue }
            reading = reading.merged(with: scan.reading)
            for (stat, value) in scan.barFractions where bars[stat] == nil { bars[stat] = value }
        }
        guard let gm = dataCenter.gamemaster, let lookup = dataCenter.lookup, let tables = PlannerMath.tables else {
            errorText = "Pokémon data is still loading. Try again in a moment."
            return
        }
        let finalReading = reading, finalBars = bars
        let result = await Task.detached(priority: .userInitiated) {
            ScreenshotImporter.propose(finalReading, barFractions: finalBars, gamemaster: gm, lookup: lookup, tables: tables)
        }.value
        if let result {
            proposal = result
        } else {
            errorText = "The CP couldn't be read. Use a screenshot of the top of the Pokémon's screen, in the English game."
        }
    }
}
