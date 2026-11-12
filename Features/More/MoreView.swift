import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Tools") {
                    NavigationLink { PlannerView() } label: {
                        Label("Planner", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink { CollectionView() } label: {
                        Label("Collection", systemImage: "square.stack.3d.up")
                    }
                    NavigationLink { RocketView() } label: {
                        Label("Rocket", systemImage: "flag.2.crossed")
                    }
                    NavigationLink { TradesView() } label: {
                        Label("Trades", systemImage: "arrow.left.arrow.right")
                    }
                }
                Section("App") {
                    NavigationLink { BackupView() } label: {
                        Label("Backup", systemImage: "externaldrive.badge.icloud")
                    }
                    NavigationLink { SettingsView() } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    NavigationLink { DataSourcesView() } label: {
                        Label("Data sources", systemImage: "tray.full")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    MoreView()
        .environment(DataCenter())
}
