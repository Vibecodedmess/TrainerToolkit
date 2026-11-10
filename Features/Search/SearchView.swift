import SwiftUI
import SwiftData
import UIKit
import SearchBuilder

struct SearchView: View {
    @State private var model = SearchBuilderModel()

    var body: some View {
        NavigationStack {
            Group {
                if let catalog = model.catalog {
                    SearchBuilderForm(model: model, catalog: catalog)
                } else {
                    ContentUnavailableView(
                        "Search terms unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(model.loadError ?? "The search term list could not be read.")
                    )
                }
            }
            .navigationTitle("Search")
        }
    }
}

private struct SearchBuilderForm: View {
    let model: SearchBuilderModel
    let catalog: SearchCatalog

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSearchPreset.createdAt) private var savedPresets: [SavedSearchPreset]
    @FocusState private var focusedField: String?
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""
    @State private var showingManage = false
    @State private var copyCount = 0
    @State private var justCopied = false

    var body: some View {
        Form {
            ForEach(catalog.groups) { group in
                Section(group.title) {
                    ForEach(group.filters) { filter in
                        FilterRow(model: model, filter: filter, focusedField: $focusedField)
                    }
                }
            }
            SearchHelpSections(catalog: catalog, notes: model.unverifiedNotes)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { previewBar }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Clear", role: .destructive) { model.clear() }
                    .disabled(model.state.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) { presetsMenu }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .alert("Save preset", isPresented: $showingSaveAlert) {
            TextField("Name", text: $newPresetName)
            Button("Save", action: savePreset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves the current filters under a name.")
        }
        .sheet(isPresented: $showingManage) {
            ManagePresetsView(catalog: catalog)
        }
        .sensoryFeedback(.success, trigger: copyCount)
        .onChange(of: model.state) { _, _ in model.saveDraft() }
    }

    private var previewBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.query.isEmpty ? "Choose filters to build a search string." : model.query)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(model.query.isEmpty ? HierarchicalShapeStyle.secondary : .primary)
                .lineLimit(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(model.query.isEmpty ? "No filters chosen" : "Search string: \(model.query)")

            if !model.unverifiedNotes.isEmpty {
                Label("Uses terms the help article doesn't confirm. See the notes at the bottom.",
                      systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button(action: copy) {
                Label(justCopied ? "Copied" : "Copy", systemImage: justCopied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.query.isEmpty)
        }
        .padding()
        .background(.bar)
    }

    private var presetsMenu: some View {
        Menu {
            Section("Built-in") {
                ForEach(catalog.presets) { preset in
                    Button {
                        model.apply(preset.state)
                    } label: {
                        Text(preset.name)
                        if let summary = preset.summary { Text(summary) }
                    }
                }
            }
            if !savedPresets.isEmpty {
                Section("Saved") {
                    ForEach(savedPresets) { preset in
                        Button(preset.name) { model.apply(preset.state) }
                    }
                }
            }
            Section {
                Button {
                    newPresetName = ""
                    showingSaveAlert = true
                } label: {
                    Label("Save current as preset…", systemImage: "square.and.arrow.down")
                }
                .disabled(model.state.isEmpty)
                if !savedPresets.isEmpty {
                    Button {
                        showingManage = true
                    } label: {
                        Label("Manage saved presets", systemImage: "list.bullet")
                    }
                }
            }
        } label: {
            Label("Presets", systemImage: "bookmark")
        }
    }

    private func copy() {
        UIPasteboard.general.string = model.query
        copyCount += 1
        justCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            justCopied = false
        }
    }

    private func savePreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        modelContext.insert(SavedSearchPreset(name: name, state: model.state))
        try? modelContext.save()
    }
}

private struct SearchHelpSections: View {
    let catalog: SearchCatalog
    let notes: [String]

    var body: some View {
        if !notes.isEmpty {
            Section {
                ForEach(notes, id: \.self) { note in
                    Label(note, systemImage: "questionmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Not confirmed by the help article")
            } footer: {
                Text("These terms are widely used but not in Niantic's article. If one doesn't work in the game, tell me and it will be fixed in search-terms.json.")
            }
        }

        Section {
            ForEach(catalog.operators.notes, id: \.text) { note in
                HStack(alignment: .firstTextBaseline) {
                    Text(note.text)
                    if !note.verified {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Not confirmed")
                    }
                }
                .font(.footnote)
            }
            if let url = URL(string: catalog.source.url) {
                Link("Source: Niantic help article on search", destination: url)
                    .font(.footnote)
            }
            Text("Term list checked \(catalog.source.checked).")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("How search strings work")
        }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: SavedSearchPreset.self, inMemory: true)
}
