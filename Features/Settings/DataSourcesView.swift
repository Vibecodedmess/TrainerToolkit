import SwiftUI
import DataSources

struct DataSourcesView: View {
    @Environment(DataCenter.self) private var dataCenter

    var body: some View {
        List {
            if let warning = dataCenter.warning {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            ForEach(dataCenter.rows) { row in
                Section {
                    SourceDetails(row: row)
                } header: {
                    Text(row.descriptor.displayName)
                }
            }

            Section {
                Button {
                    Task { await dataCenter.refreshNow() }
                } label: {
                    HStack {
                        Label("Refresh now", systemImage: "arrow.clockwise")
                        Spacer()
                        if dataCenter.isRefreshing {
                            ProgressView()
                        }
                    }
                }
                .disabled(dataCenter.isRefreshing)
            } footer: {
                Text(dataCenter.lastRunMessage
                     ?? "The app also checks automatically when opened, if the data is older than the interval set in Settings. Each source is asked at most once per 5 minutes.")
            }

            Section("Credits") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pokémon and move data")
                        .font(.subheadline.weight(.semibold))
                    Text("PvPoke gamemaster, MIT License, © pvpoke")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("github.com/pvpoke/pvpoke", destination: URL(string: "https://github.com/pvpoke/pvpoke")!)
                        .font(.footnote)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Events, raids, research and Rocket lineups")
                        .font(.subheadline.weight(.semibold))
                    Text("ScrapedDuck, with data from LeekDuck.com")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("leekduck.com", destination: URL(string: "https://leekduck.com")!)
                        .font(.footnote)
                    Link("github.com/bigfoott/ScrapedDuck", destination: URL(string: "https://github.com/bigfoott/ScrapedDuck")!)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Data sources")
        .refreshable { await dataCenter.refreshNow() }
    }
}

private struct SourceDetails: View {
    let row: DataCenter.SourceRow

    var body: some View {
        LabeledContent("Source", value: row.descriptor.provider)
        ForEach(row.state.counts, id: \.label) { count in
            LabeledContent(count.label, value: count.value.formatted())
        }
        LabeledContent("Copy in use", value: originText)
        LabeledContent("Last updated", value: updatedText)
        if let error = row.state.lastError {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last refresh failed")
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.footnote)
        }
    }

    private var originText: String {
        switch row.state.origin {
        case .downloaded: return "Downloaded"
        case .bundled: return "Built-in snapshot"
        case .missing: return "None"
        }
    }

    private var updatedText: String {
        guard let date = row.state.dataDate else { return "Never" }
        return date.formatted(.relative(presentation: .named))
    }
}

#Preview {
    NavigationStack { DataSourcesView() }
        .environment(DataCenter())
}
