import Foundation

/// The snapshot of every dataset that ships inside the app, so it works offline on first launch.
/// Files live in Sources/DataSources/Snapshots and are refreshed with scripts/update-snapshots.sh.
public enum BundledSnapshots {
    /// Folder holding `<descriptor.fileName>` files plus `manifest.json`.
    public static var directory: URL? {
        Bundle.module.url(forResource: "Snapshots", withExtension: nil)
    }

    /// When each snapshot was downloaded, from manifest.json (`{"gamemaster": "2026-11-10T09:00:00Z", ...}`).
    public static func fetchDates(in directory: URL) -> [DataSourceID: Date] {
        let url = directory.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        let formatter = ISO8601DateFormatter()
        var result: [DataSourceID: Date] = [:]
        for (key, value) in raw {
            if let id = DataSourceID(rawValue: key), let date = formatter.date(from: value) {
                result[id] = date
            }
        }
        return result
    }
}
