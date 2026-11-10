import SwiftUI
import SearchBuilder

/// Picker entries for "don't care / must have / must not have".
struct InclusionTags: View {
    var body: some View {
        Text("Any").tag(Inclusion?.none)
        Text("Yes").tag(Inclusion?.some(.include))
        Text("No").tag(Inclusion?.some(.exclude))
    }
}

/// Filter name, an "unconfirmed" marker if needed, and its note.
struct FilterLabel: View {
    let title: String
    var verified = true
    var note: String?

    init(filter: SearchCatalog.Filter, showNote: Bool = true) {
        title = filter.label
        verified = filter.verified
        note = showNote ? filter.note : nil
    }

    init(title: String, verified: Bool) {
        self.title = title
        self.verified = verified
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title)
                if !verified {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Not confirmed by the help article")
                }
            }
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FilterRow: View {
    let model: SearchBuilderModel
    let filter: SearchCatalog.Filter
    var focusedField: FocusState<String?>.Binding

    var body: some View {
        switch filter.kind {
        case .flag:
            Picker(selection: Binding(
                get: { model.flag(filter.id) },
                set: { model.setFlag(filter.id, $0) }
            )) {
                InclusionTags()
            } label: {
                FilterLabel(filter: filter)
            }

        case .options, .text:
            NavigationLink {
                if filter.kind == .options {
                    OptionsEditor(model: model, filter: filter)
                } else {
                    TextEntriesEditor(model: model, filter: filter)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    FilterLabel(filter: filter, showNote: false)
                    Text(model.summary(for: filter) ?? "Any")
                        .font(.subheadline)
                        .foregroundStyle(model.summary(for: filter) == nil ? HierarchicalShapeStyle.secondary : .primary)
                        .lineLimit(2)
                }
            }

        case .range:
            VStack(alignment: .leading, spacing: 6) {
                FilterLabel(filter: filter)
                HStack {
                    numberField("Min", id: "\(filter.id).min", text: rangeBinding(upper: false))
                    Text("to").foregroundStyle(.secondary)
                    numberField("Max", id: "\(filter.id).max", text: rangeBinding(upper: true))
                }
            }
            .padding(.vertical, 2)

        case .number:
            VStack(alignment: .leading, spacing: 6) {
                FilterLabel(filter: filter)
                numberField(filter.placeholder ?? "Number", id: filter.id, text: Binding(
                    get: { model.state.numbers[filter.id].map { String($0) } ?? "" },
                    set: { model.setNumber(filter.id, Self.parse($0)) }
                ))
            }
            .padding(.vertical, 2)
        }
    }

    private func numberField(_ placeholder: String, id: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .focused(focusedField, equals: id)
    }

    private func rangeBinding(upper: Bool) -> Binding<String> {
        Binding(
            get: { model.rangeBound(filter.id, upper: upper).map { String($0) } ?? "" },
            set: { model.setRangeBound(filter.id, upper: upper, Self.parse($0)) }
        )
    }

    /// Digits only, at most 7 of them; empty means "no value".
    static func parse(_ text: String) -> Int? {
        let digits = text.filter { $0.isASCII && $0.isNumber }.prefix(7)
        return Int(digits)
    }
}

struct OptionsEditor: View {
    let model: SearchBuilderModel
    let filter: SearchCatalog.Filter

    var body: some View {
        Form {
            Section {
                ForEach(filter.options) { option in
                    Picker(selection: Binding(
                        get: { model.option(filter.id, option.id) },
                        set: { model.setOption(filter.id, option.id, $0) }
                    )) {
                        InclusionTags()
                    } label: {
                        FilterLabel(title: option.label, verified: option.verified)
                    }
                }
            } footer: {
                Text("Yes on several = any of them. No = leave those out.")
            }
            if let note = filter.note {
                Section { Text(note).font(.footnote) }
            }
            Section {
                Button("Reset \(filter.label)", role: .destructive) {
                    for option in filter.options { model.setOption(filter.id, option.id, nil) }
                }
                .disabled(model.summary(for: filter) == nil)
            }
        }
        .navigationTitle(filter.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TextEntriesEditor: View {
    let model: SearchBuilderModel
    let filter: SearchCatalog.Filter
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private var prefix: String { filter.prefix ?? "" }
    private var cleaned: String { SearchQueryBuilder.sanitize(draft, dropping: prefix) }

    var body: some View {
        Form {
            Section {
                HStack {
                    if !prefix.isEmpty {
                        Text(prefix)
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    TextField(filter.placeholder ?? "Add", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(cleaned.isEmpty)
                }
            } footer: {
                if let note = filter.note { Text(note) }
            }

            let entries = model.entries(filter.id)
            if !entries.isEmpty {
                Section {
                    ForEach(entries) { entry in
                        Picker(selection: Binding(
                            get: { entry.inclusion },
                            set: { newValue in
                                var list = model.entries(filter.id)
                                if let index = list.firstIndex(where: { $0.id == entry.id }) {
                                    list[index].inclusion = newValue
                                    model.setEntries(filter.id, list)
                                }
                            }
                        )) {
                            Text("Yes").tag(Inclusion.include)
                            Text("No").tag(Inclusion.exclude)
                        } label: {
                            Text(prefix + SearchQueryBuilder.sanitize(entry.value, dropping: prefix))
                                .font(.body.monospaced())
                        }
                    }
                    .onDelete { offsets in
                        var list = model.entries(filter.id)
                        list.remove(atOffsets: offsets)
                        model.setEntries(filter.id, list)
                    }
                } header: {
                    Text("In this search")
                } footer: {
                    Text("Several Yes entries = any of them. No = leave it out. Swipe to remove.")
                }
            }
        }
        .navigationTitle(filter.label)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fieldFocused = model.entries(filter.id).isEmpty }
    }

    private func add() {
        guard !cleaned.isEmpty else { return }
        var list = model.entries(filter.id)
        list.append(TextEntry(value: cleaned))
        model.setEntries(filter.id, list)
        draft = ""
    }
}
