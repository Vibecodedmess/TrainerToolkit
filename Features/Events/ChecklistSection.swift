import SwiftUI
import SwiftData

/// The trainer's own to-do list for one event, stored on the device.
struct ChecklistSection: View {
    let eventID: String
    let suggestions: [String]

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [ChecklistItem]
    @State private var newTask = ""

    init(eventID: String, suggestions: [String]) {
        self.eventID = eventID
        self.suggestions = suggestions
        let id = eventID
        _items = Query(filter: #Predicate<ChecklistItem> { $0.eventID == id }, sort: \ChecklistItem.order)
    }

    private var trimmed: String { newTask.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var missingSuggestions: [String] {
        let existing = Set(items.map(\.text))
        return suggestions.filter { !existing.contains($0) }
    }

    var body: some View {
        Section {
            ForEach(items) { item in
                Button {
                    item.isDone.toggle()
                    try? modelContext.save()
                } label: {
                    Label {
                        Text(item.text)
                            .strikethrough(item.isDone)
                            .foregroundStyle(item.isDone ? HierarchicalShapeStyle.secondary : .primary)
                    } icon: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isDone ? Color.green : Color.secondary)
                    }
                }
                .accessibilityValue(item.isDone ? "Done" : "Not done")
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(items[index]) }
                try? modelContext.save()
            }

            HStack {
                TextField("Add a task", text: $newTask)
                    .submitLabel(.done)
                    .onSubmit { add([trimmed]) }
                Button("Add") { add([trimmed]) }
                    .disabled(trimmed.isEmpty)
            }

            if !missingSuggestions.isEmpty {
                Button {
                    add(missingSuggestions)
                } label: {
                    Label("Add \(missingSuggestions.count) suggested task\(missingSuggestions.count == 1 ? "" : "s")",
                          systemImage: "wand.and.stars")
                }
            }
        } header: {
            Text("My checklist")
        } footer: {
            let done = items.filter(\.isDone).count
            if !items.isEmpty {
                Text("\(done) of \(items.count) done. Swipe a task to delete it.")
            }
        }
    }

    private func add(_ texts: [String]) {
        let tasks = texts.filter { !$0.isEmpty }
        guard !tasks.isEmpty else { return }
        var order = (items.map(\.order).max() ?? -1) + 1
        for text in tasks {
            modelContext.insert(ChecklistItem(eventID: eventID, text: text, order: order))
            order += 1
        }
        try? modelContext.save()
        if tasks.contains(trimmed) { newTask = "" }
    }
}
