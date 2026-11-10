import SwiftUI
import SwiftData
import SearchBuilder

struct ManagePresetsView: View {
    let catalog: SearchCatalog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSearchPreset.createdAt) private var presets: [SavedSearchPreset]

    var body: some View {
        NavigationStack {
            List {
                ForEach(presets) { preset in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.name)
                        Text(SearchQueryBuilder.build(preset.state, in: catalog))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(presets[index]) }
                    try? modelContext.save()
                }
            }
            .overlay {
                if presets.isEmpty {
                    ContentUnavailableView("No saved presets", systemImage: "bookmark")
                }
            }
            .navigationTitle("Saved presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
