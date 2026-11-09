import Foundation

/// Extra practice after the day's reviews. None of these change the schedule.
public enum PracticeKind: String, CaseIterable, Identifiable, Sendable {
    /// The words missed most often in your notes (count column), then the ones in the lowest box.
    case hardest
    /// A random mix of every card.
    case random
    /// Every card answered today, in the order they were answered.
    case today

    public var id: String { rawValue }
}

public enum Practice {
    /// Cards in one practice round. See MECHANICS.md.
    public static let roundSize = 10

    public static func pick(_ kind: PracticeKind, from entries: [VocabEntry], states: [String: CardState],
                            today: Day, calendar: Calendar, limit: Int = roundSize,
                            seed: UInt64 = UInt64.random(in: 1...UInt64.max)) -> [VocabEntry] {
        switch kind {
        case .hardest:
            let sorted = entries.enumerated().sorted { a, b in
                let ab = states[a.element.word]?.box ?? 0, bb = states[b.element.word]?.box ?? 0
                if a.element.count != b.element.count { return a.element.count > b.element.count }
                if ab != bb { return ab < bb }
                return a.offset < b.offset
            }
            return Array(sorted.map(\.element).prefix(limit))
        case .random:
            var rng = SplitMix64(seed: seed)
            return Array(entries.shuffled(using: &rng).prefix(limit))
        case .today:
            return entries
                .compactMap { e -> (VocabEntry, Date)? in
                    guard let r = states[e.word]?.lastReviewed, Day(r, calendar: calendar) == today else { return nil }
                    return (e, r)
                }
                .sorted { $0.1 < $1.1 }
                .map(\.0)
        }
    }

    /// How many cards each kind would give right now.
    public static func available(_ kind: PracticeKind, from entries: [VocabEntry], states: [String: CardState],
                                 today: Day, calendar: Calendar) -> Int {
        switch kind {
        case .hardest, .random: return min(entries.count, roundSize)
        case .today: return pick(.today, from: entries, states: states, today: today, calendar: calendar, limit: .max).count
        }
    }
}

/// A small seeded random generator, so a practice round can be repeated in tests.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
