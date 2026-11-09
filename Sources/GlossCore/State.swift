import Foundation

/// Quiz results for one day.
public struct DailyStats: Codable, Equatable, Sendable {
    public var answered: Int = 0
    public var correct: Int = 0
    public var newIntroduced: Int = 0
    public init(answered: Int = 0, correct: Int = 0, newIntroduced: Int = 0) {
        self.answered = answered
        self.correct = correct
        self.newIntroduced = newIntroduced
    }
    public var accuracy: Double { answered == 0 ? 0 : Double(correct) / Double(answered) }
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
