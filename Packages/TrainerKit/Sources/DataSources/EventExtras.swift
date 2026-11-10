import Foundation

/// The type-specific `extraData` of a ScrapedDuck event, as plain values (no image URLs).
/// Field names follow the ScrapedDuck wiki ("Extra Data"). Anything missing is just empty.
public struct EventExtras: Sendable, Hashable {
    public struct ResearchStep: Sendable, Hashable {
        public let name: String
        public let step: Int?
        public let tasks: [(task: String, reward: String)]
        public let rewards: [String]

        public static func == (a: ResearchStep, b: ResearchStep) -> Bool {
            a.name == b.name && a.step == b.step && a.rewards == b.rewards
                && a.tasks.map(\.task) == b.tasks.map(\.task) && a.tasks.map(\.reward) == b.tasks.map(\.reward)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(step)
        }
    }

    /// Community Day: Pokémon appearing more often.
    public var spawns: [String] = []
    /// Shiny-eligible Pokémon (Community Day and raids).
    public var shinies: [String] = []
    public var bonuses: [String] = []
    public var bonusDisclaimers: [String] = []
    public var specialResearch: [ResearchStep] = []
    /// Raid battles: bosses (with shiny flag).
    public var raidBosses: [(name: String, canBeShiny: Bool)] = []
    /// Spotlight Hour / Research Breakthrough featured Pokémon.
    public var featured: [String] = []
    /// Spotlight Hour bonus, e.g. "2× Catch Candy".
    public var spotlightBonus: String?
    public var hasSpawns: Bool?
    public var hasFieldResearchTasks: Bool?

    public init() {}

    public init(_ json: JSONValue?) {
        guard let json else { return }
        if let generic = json["generic"] {
            hasSpawns = generic["hasSpawns"]?.boolValue
            hasFieldResearchTasks = generic["hasFieldResearchTasks"]?.boolValue
        }
        if let cd = json["communityday"] {
            spawns = cd["spawns"]?.names ?? []
            shinies = cd["shinies"]?.names ?? []
            bonuses = (cd["bonuses"]?.arrayValue ?? []).compactMap { $0["text"]?.stringValue.map(Self.plainText) }
            bonusDisclaimers = (cd["bonusDisclaimers"]?.arrayValue ?? []).compactMap { $0.stringValue.map(Self.plainText) }
            specialResearch = (cd["specialresearch"]?.arrayValue ?? []).compactMap(Self.researchStep)
        }
        if let raids = json["raidbattles"] {
            raidBosses = (raids["bosses"]?.arrayValue ?? []).compactMap { boss in
                guard let name = boss["name"]?.stringValue else { return nil }
                return (name, boss["canBeShiny"]?.boolValue ?? false)
            }
            shinies = Self.merge(shinies, raids["shinies"]?.names ?? [])
        }
        if let spotlight = json["spotlight"] {
            let list = spotlight["list"]?.names ?? []
            featured = list.isEmpty ? [spotlight["name"]?.stringValue].compactMap { $0 } : list
            spotlightBonus = spotlight["bonus"]?.stringValue.map(Self.plainText)
        }
        if let breakthrough = json["breakthrough"], let name = breakthrough["name"]?.stringValue {
            featured = Self.merge(featured, [name])
        }
    }

    public var isEmpty: Bool {
        spawns.isEmpty && shinies.isEmpty && bonuses.isEmpty && specialResearch.isEmpty
            && raidBosses.isEmpty && featured.isEmpty
    }

    public static func == (a: EventExtras, b: EventExtras) -> Bool {
        a.spawns == b.spawns && a.shinies == b.shinies && a.bonuses == b.bonuses
            && a.bonusDisclaimers == b.bonusDisclaimers && a.specialResearch == b.specialResearch
            && a.raidBosses.map(\.name) == b.raidBosses.map(\.name) && a.featured == b.featured
            && a.spotlightBonus == b.spotlightBonus
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(spawns)
        hasher.combine(featured)
    }

    private static func researchStep(_ json: JSONValue) -> ResearchStep? {
        guard let name = json["name"]?.stringValue else { return nil }
        let tasks: [(task: String, reward: String)] = (json["tasks"]?.arrayValue ?? []).compactMap { task in
            guard let text = task["text"]?.stringValue else { return nil }
            return (plainText(text), plainText(task["reward"]?["text"]?.stringValue ?? ""))
        }
        let rewards = (json["rewards"]?.arrayValue ?? []).compactMap { $0["text"]?.stringValue.map(plainText) }
        let step = json["step"]?.numberValue.map { Int($0) }
        return ResearchStep(name: plainText(name), step: step, tasks: tasks, rewards: rewards)
    }

    private static func merge(_ a: [String], _ b: [String]) -> [String] {
        var result = a
        for item in b where !result.contains(item) { result.append(item) }
        return result
    }

    /// Removes HTML tags ("Poké Ball <span>×15</span>" -> "Poké Ball ×15") and tidies spaces.
    public static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&nbsp;": " ", "&#39;": "'", "&quot;": "\"", "&lt;": "<", "&gt;": ">"]
        for (entity, char) in entities { text = text.replacingOccurrences(of: entity, with: char) }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

extension JSONValue {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    /// For arrays of {"name": ...} objects.
    var names: [String] {
        (arrayValue ?? []).compactMap { $0["name"]?.stringValue }
    }
}

extension SDEvent {
    public var extras: EventExtras { EventExtras(extraData) }
}
