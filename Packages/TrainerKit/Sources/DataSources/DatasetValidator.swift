import Foundation

/// A labelled number shown on the Data sources screen, e.g. "Pokémon: 1752".
public struct DatasetCount: Codable, Sendable, Hashable {
    public let label: String
    public let value: Int

    public init(label: String, value: Int) {
        self.label = label
        self.value = value
    }
}

public struct DatasetValidationError: Error, LocalizedError, Equatable {
    public let message: String
    public var errorDescription: String? { message }
}

/// Checks that downloaded (or bundled) data still has the format the app expects.
/// A copy that fails validation is never used; the last good copy stays in place.
public enum DatasetValidator {
    /// More than this share of unreadable entries means the format probably changed.
    static let maxFailureShare = 0.1

    public static func validate(_ data: Data, for id: DataSourceID) throws -> [DatasetCount] {
        do {
            switch id {
            case .gamemaster:
                let gm = try JSONDecoder().decode(Gamemaster.self, from: data)
                try check(valid: gm.pokemon.count, failures: gm.skippedEntries, what: "Pokémon entries")
                try check(valid: gm.moves.count, failures: 0, what: "moves")
                return [DatasetCount(label: "Pokémon", value: gm.pokemon.count),
                        DatasetCount(label: "Moves", value: gm.moves.count)]
            case .events:
                return [try count(SDEvent.self, in: data, label: "Events")]
            case .raids:
                return [try count(SDRaidBoss.self, in: data, label: "Raid bosses")]
            case .research:
                return [try count(SDResearchTask.self, in: data, label: "Research tasks")]
            case .rocketLineups:
                return [try count(SDRocketLineup.self, in: data, label: "Lineups")]
            }
        } catch let error as DatasetValidationError {
            throw error
        } catch {
            throw DatasetValidationError(message: "Unexpected data format (\(shortDescription(of: error)))")
        }
    }

    private static func count<T: Decodable>(_ type: T.Type, in data: Data, label: String) throws -> DatasetCount {
        let list = try JSONDecoder().decode(LossyArray<T>.self, from: data)
        try check(valid: list.elements.count, failures: list.failures, what: label.lowercased())
        return DatasetCount(label: label, value: list.elements.count)
    }

    private static func check(valid: Int, failures: Int, what: String) throws {
        guard valid > 0 else {
            throw DatasetValidationError(message: "No \(what) found")
        }
        let total = Double(valid + failures)
        if Double(failures) / total > maxFailureShare {
            throw DatasetValidationError(message: "\(failures) of \(valid + failures) \(what) unreadable; format may have changed")
        }
    }

    private static func shortDescription(of error: Error) -> String {
        switch error {
        case DecodingError.dataCorrupted: return "not valid JSON"
        case DecodingError.keyNotFound(let key, _): return "missing \"\(key.stringValue)\""
        case DecodingError.typeMismatch: return "type mismatch"
        case DecodingError.valueNotFound: return "missing value"
        default: return error.localizedDescription
        }
    }
}
