import SwiftUI
import GameMath
import DataSources
import ScreenshotImport

/// Review one Pokémon read from screenshots: what was read, the species and level/IV choice,
/// shiny, then the normal editor to save it.
struct ScreenshotReviewView: View {
    let proposal: ScreenshotImporter.Proposal

    @Environment(DataCenter.self) private var dataCenter
    @State private var speciesId: String?
    @State private var solutionId: String?
    @State private var showAllSolutions = false
    /// The game's shiny mark can't be read reliably from a screenshot, so the user sets it here.
    @State private var isShiny = false

    var body: some View {
        Form {
            readSection
            resultSections
        }
        .navigationTitle(proposal.certainChoice?.option.pokemon.speciesName ?? proposal.reading.name ?? "Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var readSection: some View {
        let r = proposal.reading
        return Section {
            LabeledContent("CP", value: r.cp.map(String.init) ?? "Not found")
            LabeledContent("HP", value: r.hp.map(String.init) ?? "Not found")
            LabeledContent("Name", value: r.name ?? "Not found")
            if let family = r.candyFamily { LabeledContent("Candy", value: family) }
            if !r.types.isEmpty { LabeledContent("Type") { TypeBadges(types: r.types) } }
            LabeledContent("Power-up stardust", value: r.powerUpStardust.map { $0.formatted() } ?? "Not found")
            LabeledContent("Appraisal IVs", value: barText(proposal.barIVs))
            if proposal.isShadow { Label("Shadow (PURIFY button found)", systemImage: "flame.fill") }
            if proposal.isLucky { Label("Lucky", systemImage: "star.circle") }
        } header: {
            Text("Read from the screenshots")
        } footer: {
            if proposal.ignoredStardust {
                Text("No level fits the power-up stardust that was read, so it was ignored. Check the level below.")
            }
        }
    }

    @ViewBuilder
    private var resultSections: some View {
        if proposal.options.isEmpty {
            Section {
                Text("No Pokémon, level and IVs fit what was read. Check that the screenshots show one Pokémon, or add it by hand.")
                    .foregroundStyle(.secondary)
            }
        } else if let lookup = dataCenter.lookup {
            let option = proposal.options.first { $0.pokemon.speciesId == speciesId } ?? proposal.options[0]
            Section {
                if proposal.options.count > 1 {
                    Picker("Pokémon", selection: Binding(get: { option.pokemon.speciesId }, set: { speciesId = $0; solutionId = nil })) {
                        ForEach(proposal.options) { Text($0.pokemon.speciesName).tag($0.pokemon.speciesId) }
                    }
                } else {
                    LabeledContent("Pokémon", value: option.pokemon.speciesName)
                }
                LabeledContent("Moves", value: movesText(proposal.moves(for: option.pokemon, lookup: lookup), lookup: lookup))
                Toggle(isOn: $isShiny) {
                    Label("Shiny", systemImage: "sparkles")
                }
            } header: {
                Text("Pokémon")
            } footer: {
                if proposal.options.count > 1 {
                    Text("More than one Pokémon fits (a nickname, or regional forms). Pick the right one. Shiny can't be read from screenshots, so set it here.")
                } else {
                    Text("Shiny can't be read from screenshots, so set it here.")
                }
            }
            solutionsSection(option)
            Section {
                NavigationLink {
                    CollectionEditorView(prefilled: proposal.draft(option: option, solution: selectedSolution(option),
                                                                   isShiny: isShiny, lookup: lookup))
                } label: {
                    Label("Review and save", systemImage: "square.and.pencil")
                }
            } footer: {
                Text("Opens the normal editor with these values. Check them, then tap Save.")
            }
        }
    }

    private func selectedSolution(_ option: ScreenshotImporter.SpeciesOption) -> IVSolver.Solution {
        if let id = solutionId, let s = option.solutions.first(where: { $0.id == id }) { return s }
        if let certain = proposal.certainChoice, certain.option.id == option.id { return certain.solution }
        return option.solutions[0]
    }

    private func solutionsSection(_ option: ScreenshotImporter.SpeciesOption) -> some View {
        let all = option.solutions
        let shown = showAllSolutions ? Array(all.prefix(60)) : Array(all.prefix(6))
        let selected = selectedSolution(option)
        let barsMissing = proposal.barIVs.isEmpty
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

    private func barText(_ hints: IVSolver.Hints) -> String {
        guard !hints.isEmpty else { return "No appraisal found" }
        return [hints.attack, hints.defense, hints.stamina].map { $0.map(String.init) ?? "?" }.joined(separator: "/")
    }

    private func movesText(_ moves: (fast: String?, charged: [String]), lookup: GamemasterLookup) -> String {
        let names = ([moves.fast].compactMap { $0 } + moves.charged).map { lookup.moveName($0) }
        return names.isEmpty ? "Not found" : names.joined(separator: ", ")
    }
}
