import Foundation

/// Small on-device record used to check that app data survives re-signing.
/// UserDefaults lives in the app's data container, the same place the SwiftData
/// store will live, so if these values survive a reinstall, so will your data.
enum InstallInfo {
    private static let firstLaunchKey = "install.firstLaunch"
    private static let launchCountKey = "install.launchCount"

    static func recordLaunch(defaults: UserDefaults = .standard) {
        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(Date(), forKey: firstLaunchKey)
        }
        defaults.set(defaults.integer(forKey: launchCountKey) + 1, forKey: launchCountKey)
    }

    static var firstLaunch: Date? {
        UserDefaults.standard.object(forKey: firstLaunchKey) as? Date
    }

    static var launchCount: Int {
        UserDefaults.standard.integer(forKey: launchCountKey)
    }

    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
