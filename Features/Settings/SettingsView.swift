import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink { DataSourcesView() } label: {
                    Label("Data sources", systemImage: "tray.full")
                }
            } header: {
                Text("Data")
            }

            Section {
                LabeledContent("Version", value: InstallInfo.versionString)
                LabeledContent("Bundle ID", value: InstallInfo.bundleID)
                LabeledContent("First launch", value: firstLaunchText)
                LabeledContent("Launch count", value: "\(InstallInfo.launchCount)")
            } header: {
                Text("Install check")
            } footer: {
                Text("Stored on this device in the app's data container. If First launch and Launch count are still here after you re-sign and reinstall, your app data survived too.")
            }
        }
        .navigationTitle("Settings")
    }

    private var firstLaunchText: String {
        guard let date = InstallInfo.firstLaunch else { return "Unknown" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
