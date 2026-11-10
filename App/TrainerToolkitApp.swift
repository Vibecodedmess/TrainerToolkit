import SwiftUI
import SwiftData
import DataSources

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
                .task {
                    await dataCenter.start()
                    // Event times may have changed since last launch: rebuild local reminders.
                    await ReminderScheduler.sync(context: modelContainer.mainContext,
                                                 events: EventCalendar.resolve(dataCenter.events))
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await dataCenter.refreshIfStale() }
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
