import SwiftUI

@main
struct TrainerToolkitApp: App {
    @State private var dataCenter = DataCenter()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        InstallInfo.recordLaunch()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(dataCenter)
                .task { await dataCenter.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await dataCenter.refreshIfStale() }
                    }
                }
        }
    }
}
