import SwiftUI
import SwiftData
import DataSources

/// Add or edit one want-list entry: a species from the gamemaster and/or a free-text note.
struct WantEditorView: View {
    let friend: TradeFriend
    /// nil = new entry (shown in a sheet with Cancel).
    let want: TradeWant?
    let theyWant: Bool

    @Environment(DataCenter.self) private var dataCenter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var speciesId: String
    @State private var speciesName: String
    @State private var note: String
    @State private var isShiny: Bool
    @State private var isDone: Bool
    @State private var confirmDelete = false
    @FocusState private var keyboardFocused: Bool

    init(friend: TradeFriend, want: TradeWant?, theyWant: Bool) {
        self.friend = friend
        self.want = want
        self.theyWant = want?.theyWant ?? theyWant
        _speciesId = State(initialValue: want?.speciesId ?? "")
        _speciesName = State(initialValue: want?.speciesName ?? "")
        _note = State(initialValue: want?.note ?? "")
        _isShiny = State(initialValue: want?.isShiny ?? false)
        _isDone = State(initialValue: want?.isDone ?? false)
    }

    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !speciesId.isEmpty || !trimmedNote.isEmpty }
    private var types: [String] {
        guard !speciesId.isEmpty else { return [] }
        return dataCenter.lookup?.pokemon(id: speciesId)?.realTypes ?? []
    }

    var body: some View {
        Form {
            Section {
                if dataCenter.gamemaster != nil {
                    NavigationLink {
                        SpeciesPicker(candidates: dataCenter.powerUpCandidates) { pokemon in
                            speciesId = pokemon.speciesId
                            speciesName = pokemon.speciesName
                        }
                    } label: {
                        HStack {
                            Text(speciesId.isEmpty ? "Choose Pokémon" : speciesName)
                                .foregroundStyle(speciesId.isEmpty ? HierarchicalShapeStyle.secondary : .primary)
                            Spacer()
                            TypeBadges(types: types)
                        }
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("Loading Pokémon data…").foregroundStyle(.secondary)
                    }
                }
                if !speciesId.isEmpty {
                    Button("Clear Pokémon", role: .destructive) {
                        speciesId = ""
                        speciesName = ""
                    }
                }
            } header: {
                Text("Pokémon")
            }
            Section {
                TextField("For example a form, costume or IVs", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($keyboardFocused)
            } header: {
                Text("Note")
            } footer: {
                Text("Choose a Pokémon, write a note, or both.")
            }
            Section {
                Toggle("Shiny", isOn: $isShiny)
                Toggle("Done", isOn: $isDone)
            }
            if want != nil {
                Section {
                    Button("Remove from list", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(want == nil ? (theyWant ? "They want" : "I want") : "Edit entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if want == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { keyboardFocused = false }
            }
        }
        .confirmationDialog("Remove this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive, action: delete)
        }
    }

    private func save() {
        let target: TradeWant
        if let want {
            target = want
        } else {
            target = TradeWant(theyWant: theyWant)
            modelContext.insert(target)
            target.friend = friend
        }
        target.speciesId = speciesId
        target.speciesName = speciesName
        target.note = trimmedNote
        target.isShiny = isShiny
        target.isDone = isDone
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let want else { return }
        let id = want.persistentModelID
        friend.wants.removeAll { $0.persistentModelID == id }
        modelContext.delete(want)
        try? modelContext.save()
        dismiss()
    }
}
