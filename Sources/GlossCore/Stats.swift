import Foundation

public struct CategoryCount: Equatable, Hashable, Sendable, Identifiable {
    public var category: String
    public var count: Int
    public var id: String { category }
    public init(category: String, count: Int) {
        self.category = category
        self.count = count
    }
}

public struct DayAccuracy: Equatable, Sendable, Identifiable {
    public var day: Day
    public var answered: Int
    public var correct: Int
    public var id: String { day.iso }
    public var accuracy: Double { answered == 0 ? 0 : Double(correct) / Double(answered) }
}

public enum GlossStats {
    /// Mistakes per category over the last `days` days, ending on `today` (inclusive).
    /// Every known category is listed, also with 0. Unknown tags follow.
    public static func categoryCounts(_ mistakes: [Mistake], lastDays days: Int, today: Day, calendar: Calendar) -> [CategoryCount] {
        let first = today.adding(days: -(days - 1), calendar: calendar)
        var counts: [String: Int] = [:]
        for m in mistakes {
            guard let d = m.day, d >= first, d <= today else { continue }
            for c in m.categories { counts[c, default: 0] += 1 }
        }
        var out = MistakeCategory.known.map { CategoryCount(category: $0, count: counts[$0] ?? 0) }
        let extra = counts.keys.filter { !MistakeCategory.known.contains($0) }.sorted()
        out += extra.map { CategoryCount(category: $0, count: counts[$0]!) }
        return out
    }

    /// The most repeated spelling words (by the count column, then by word).
    public static func topRepeated(_ entries: [VocabEntry], limit: Int = 10) -> [VocabEntry] {
        Array(entries.sorted { $0.count != $1.count ? $0.count > $1.count : $0.word < $1.word }.prefix(limit))
    }

    /// Quiz accuracy for each of the last `days` days, oldest first.
    public static func accuracy(_ state: GlossState, lastDays days: Int, today: Day, calendar: Calendar) -> [DayAccuracy] {
        (0..<days).reversed().map { back in
            let d = today.adding(days: -back, calendar: calendar)
            let s = state.stats(for: d)
            return DayAccuracy(day: d, answered: s.answered, correct: s.correct)
        }
    }
}
