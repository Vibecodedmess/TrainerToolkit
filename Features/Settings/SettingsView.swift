import SwiftUI

struct SettingsView: View {
    @AppStorage(DataSettings.refreshIntervalKey) private var refreshHours = DataSettings.defaultRefreshHours
    @Environment(DataCenter.self) private var dataCenter

    var body: some View {
        Form {
            Section {
                Picker("Check for new data", selection: $refreshHours) {
                    ForEach(DataSettings.refreshChoices, id: \.self) { hours in
                        Text("Every \(hours) hours").tag(hours)
                    }
                }
                NavigationLink { DataSourcesView() } label: {
                    HStack {
                        Label("Data sources", systemImage: "tray.full")
                        if dataCenter.warning != nil {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .accessibilityLabel("Some data couldn't update")
                        }
                    }
                }
            } header: {
                Text("Data")
            } footer: {
                Text("When you open the app, data older than this is refreshed in the background.")
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
        .environment(DataCenter())
}
