import Foundation

/// Small on-device record used to check that app data survives re-signing.
/// UserDefaults lives in the app's data container, the same place the SwiftData
/// store lives, so if these values survive a reinstall, so does your data.
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

    /// When this install stops opening: the `ExpirationDate` of the provisioning profile Sideloadly
    /// signs the app with (7 days for a free Apple ID). Nil when there's no profile (simulator, CI).
    static let signingExpiry: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return profileExpiry(data)
    }()

    /// The profile is a signed (CMS) file with a plain XML property list inside.
    static func profileExpiry(_ data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound],
                                                                       format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }

    /// Home banner when the install expires within 2 days, else nil.
    static func expiryWarning(now: Date = .now) -> String? {
        guard let expiry = signingExpiry, expiry.timeIntervalSince(now) < 2 * 24 * 3600 else { return nil }
        if expiry <= now { return "This install's signature has expired. Back up, then re-sign with Sideloadly." }
        return "This install expires \(expiry.formatted(.relative(presentation: .named))). Back up, then re-sign with Sideloadly."
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
