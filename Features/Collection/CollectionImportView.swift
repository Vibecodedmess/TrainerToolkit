import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CollectionImport
import DataSources
import GameMath

/// Imports Pokémon from a CSV in the app's own format (see COLLECTION_IMPORT.md).
/// Shows a preview with problems and duplicates before anything is saved.
struct CollectionImportView: View {
    @Environment(DataCenter.self) private var dataCenter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [CollectedPokemon]

    @State private var showingPicker = false
    @State private var fileName: String?
    @State private var resolved: CollectionCSV.Resolved?
    @State private var missingColumns: [String] = []
    @State private var readError: String?
    @State private var includeDuplicates = false
    @State private var importedCount: Int?
    @State private var templateURL: URL?

    var body: some View {
        List {
            Section {
                Button {
                    showingPicker = true
                } label: {
                    Label(fileName == nil ? "Choose a CSV file" : "Choose another file", systemImage: "doc.badge.plus")
                }
                if let fileName {
                    LabeledContent("File", value: fileName)
                }
            } footer: {
                Text("Required columns: Name, CP, Attack, Defense, HP (the IVs, 0–15). Optional: moves, Shadow, Purified, Shiny, Lucky, Level, Nickname, Notes. Comma or semicolon separated.")
            }

            if let importedCount {
                Section {
                    Label("Imported \(importedCount) Pokémon.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button("Done") { dismiss() }
                }
            }

            if let readError {
                Section {
                    Label(readError, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }

            if !missingColumns.isEmpty {
                Section {
                    Text("The file is missing these columns: \(missingColumns.joined(separator: ", ")).")
                } header: {
                    Text("Can't import this file")
                } footer: {
                    Text("Check the header row, or start from the template below.")
                }
            }

            if let resolved {
                resultSections(resolved)
            }

            Section {
                if let templateURL {
                    ShareLink(item: templateURL) {
                        Label("Share an empty template", systemImage: "square.and.arrow.up")
                    }
                }
                Text(CollectionCSV.templateHeader)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            } header: {
                Text("Template")
            } footer: {
                Text("Open the template in Google Sheets, Excel or Numbers, add one Pokémon per row, export as CSV, then choose that file here. Moves can be names like \"Mud Shot\"; Shadow/Shiny/Lucky take yes or no.")
            }
        }
        .navigationTitle("Import CSV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .fileImporter(isPresented: $showingPicker,
                      allowedContentTypes: [.commaSeparatedText, .plainText, .text, .data]) { result in
            handle(result)
        }
        .task { templateURL = Self.writeTemplate() }
    }

    // MARK: - Preview

    @ViewBuilder
    private func resultSections(_ resolved: CollectionCSV.Resolved) -> some View {
        let keys = Set(existing.map { Self.key($0) })
        let duplicates = resolved.candidates.filter { keys.contains(Self.key($0)) }
        let toImport = includeDuplicates ? resolved.candidates : resolved.candidates.filter { !keys.contains(Self.key($0)) }

        Section {
            LabeledContent("Ready to import", value: "\(toImport.count)")
            if !duplicates.isEmpty {
                LabeledContent("Already in your collection", value: "\(duplicates.count)")
                Toggle("Import duplicates too", isOn: $includeDuplicates)
            }
            if !resolved.problems.isEmpty {
                LabeledContent("Rows with problems (skipped)", value: "\(resolved.problems.count)")
            }
            Button {
                importCandidates(toImport)
            } label: {
                Label("Import \(toImport.count) Pokémon", systemImage: "square.and.arrow.down")
            }
            .disabled(toImport.isEmpty)
        } header: {
            Text("Summary")
        }

        if !resolved.candidates.isEmpty {
            Section("Preview") {
                ForEach(resolved.candidates) { candidate in
                    CandidateRow(candidate: candidate, isDuplicate: keys.contains(Self.key(candidate)))
                }
            }
        }

        if !resolved.problems.isEmpty {
            Section("Not imported") {
                ForEach(resolved.problems) { problem in
                    Text("Line \(problem.line): \(problem.message)")
                        .font(.footnote)
                }
            }
        }
    }

    // MARK: - Actions

    private func handle(_ result: Result<URL, Error>) {
        importedCount = nil
        readError = nil
        missingColumns = []
        resolved = nil
        includeDuplicates = false
        switch result {
        case .failure(let error):
            readError = "Couldn't open the file: \(error.localizedDescription)"
        case .success(let url):
            fileName = url.lastPathComponent
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let table = try CSVReader.read(Data(contentsOf: url))
                let parsed = CollectionCSV.parse(table)
                missingColumns = parsed.missingColumns
                guard parsed.missingColumns.isEmpty else { return }
                guard let lookup = dataCenter.lookup, let tables = PlannerMath.tables else {
                    readError = "Pokémon data is still loading. Try again in a moment."
                    return
                }
                resolved = CollectionCSV.resolve(parsed, lookup: lookup, levels: tables)
            } catch {
                readError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func importCandidates(_ candidates: [CollectionCSV.Candidate]) {
        for c in candidates {
            let p = CollectedPokemon(speciesId: c.speciesId, speciesName: c.speciesName,
                                     baseAttack: c.base.attack, baseDefense: c.base.defense, baseStamina: c.base.stamina,
                                     levelHalfSteps: c.level.halfSteps, source: "csv")
            p.ivAttack = c.ivs.attack
            p.ivDefense = c.ivs.defense
            p.ivStamina = c.ivs.stamina
            p.fastMoveId = c.fastMoveId
            p.chargedMoveId = c.chargedMoveId
            p.secondChargedMoveId = c.secondChargedMoveId
            p.isShadow = c.isShadow
            p.isPurified = c.isPurified
            p.isShiny = c.isShiny
            p.isLucky = c.isLucky
            p.nickname = c.nickname
            p.notes = c.notes
            modelContext.insert(p)
        }
        try? modelContext.save()
        importedCount = candidates.count
        resolved = nil
        fileName = nil
    }

    // MARK: - Helpers

    /// Same species, IVs, level and shadow status = treated as the same Pokémon.
    static func key(_ p: CollectedPokemon) -> String {
        "\(p.speciesId)|\(p.ivAttack)|\(p.ivDefense)|\(p.ivStamina)|\(p.levelHalfSteps)|\(p.isShadow)"
    }

    static func key(_ c: CollectionCSV.Candidate) -> String {
        "\(c.speciesId)|\(c.ivs.attack)|\(c.ivs.defense)|\(c.ivs.stamina)|\(c.level.halfSteps)|\(c.isShadow)"
    }

    static func writeTemplate() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("trainer-toolkit-collection-template.csv")
        do {
            try (CollectionCSV.templateHeader + "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

private struct CandidateRow: View {
    let candidate: CollectionCSV.Candidate
    let isDuplicate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(candidate.nickname.isEmpty ? candidate.speciesName : "\(candidate.nickname) (\(candidate.speciesName))")
                    .font(.subheadline.weight(.semibold))
                if candidate.isShadow { Image(systemName: "flame.fill").foregroundStyle(.purple).accessibilityLabel("Shadow") }
                if candidate.isShiny { Image(systemName: "sparkles").foregroundStyle(.yellow).accessibilityLabel("Shiny") }
                Spacer()
                if isDuplicate {
                    Text("Already added")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text("L\(candidate.level.description) · \(candidate.ivs.attack)/\(candidate.ivs.defense)/\(candidate.ivs.stamina) (\(candidate.ivs.percent)%)")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(candidate.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
