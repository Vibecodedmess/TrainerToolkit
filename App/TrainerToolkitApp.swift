import SwiftUI
import SwiftData

@main
struct TrainerToolkitApp: App {
    @State private var dataCenter = DataCenter()
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer: ModelContainer

    init() {
        InstallInfo.recordLaunch()
        modelContainer = AppModelContainer.make().container
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
        .modelContainer(modelContainer)
    }
}
