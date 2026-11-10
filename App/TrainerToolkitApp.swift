import SwiftUI

@main
struct TrainerToolkitApp: App {
    init() {
        InstallInfo.recordLaunch()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
