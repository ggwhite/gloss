import Foundation

/// Quiz results for one day.
public struct DailyStats: Codable, Equatable, Sendable {
    /// Scheduled reviews answered (these count for accuracy).
    public var answered: Int = 0
    public var correct: Int = 0
    public var newIntroduced: Int = 0
    /// Extra practice answered; it never changes the schedule or the accuracy.
    public var practiced: Int = 0
    public var practiceCorrect: Int = 0
    /// New cards added on top of the daily limit ("Learn 10 more").
    public var extraNew: Int = 0

    public init(answered: Int = 0, correct: Int = 0, newIntroduced: Int = 0,
                practiced: Int = 0, practiceCorrect: Int = 0, extraNew: Int = 0) {
        self.answered = answered
        self.correct = correct
        self.newIntroduced = newIntroduced
        self.practiced = practiced
        self.practiceCorrect = practiceCorrect
        self.extraNew = extraNew
    }

    public var accuracy: Double { answered == 0 ? 0 : Double(correct) / Double(answered) }

    private enum CodingKeys: String, CodingKey {
        case answered, correct, newIntroduced, practiced, practiceCorrect, extraNew
    }

    /// Older state files have only the first three fields; the rest default to 0.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        answered = try c.decodeIfPresent(Int.self, forKey: .answered) ?? 0
        correct = try c.decodeIfPresent(Int.self, forKey: .correct) ?? 0
        newIntroduced = try c.decodeIfPresent(Int.self, forKey: .newIntroduced) ?? 0
        practiced = try c.decodeIfPresent(Int.self, forKey: .practiced) ?? 0
        practiceCorrect = try c.decodeIfPresent(Int.self, forKey: .practiceCorrect) ?? 0
        extraNew = try c.decodeIfPresent(Int.self, forKey: .extraNew) ?? 0
    }
}

/// Everything saved in `state.json`. Cards are keyed by the correct spelling.
public struct GlossState: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var cards: [String: CardState] = [:]
    public var daily: [String: DailyStats] = [:]
    public init() {}

    public func stats(for day: Day) -> DailyStats { daily[day.iso] ?? DailyStats() }
}

/// Reads and writes `~/Library/Application Support/Gloss/state.json`.
public struct StateStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Gloss", isDirectory: true).appendingPathComponent("state.json")
    }

    public func load() -> GlossState {
        guard let data = try? Data(contentsOf: url) else { return GlossState() }
        return (try? Self.decoder.decode(GlossState.self, from: data)) ?? GlossState()
    }

    public func save(_ state: GlossState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try Self.encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
