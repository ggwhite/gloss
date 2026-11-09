import Foundation

/// The saved progress of one card.
public struct CardState: Codable, Equatable, Sendable {
    /// Leitner box 1...5. A card without a state is new.
    public var box: Int
    /// The card is not shown before this moment.
    public var due: Date
    /// The last day the card was answered correctly. It is not shown again that day.
    public var lastCorrectDay: Day?
    public var reviews: Int
    public var correct: Int
    public var lastReviewed: Date?

    public init(box: Int, due: Date, lastCorrectDay: Day? = nil, reviews: Int = 0, correct: Int = 0, lastReviewed: Date? = nil) {
        self.box = box
        self.due = due
        self.lastCorrectDay = lastCorrectDay
        self.reviews = reviews
        self.correct = correct
        self.lastReviewed = lastReviewed
    }
}

/// Leitner boxes 1–5 with fixed intervals.
public struct LeitnerScheduler: Sendable {
    /// Seconds until the next review for each box. See MECHANICS.md.
    public static let intervals: [TimeInterval] = [
        10 * 60,          // box 1: 10 minutes
        1 * 86_400,       // box 2: 1 day
        3 * 86_400,       // box 3: 3 days
        7 * 86_400,       // box 4: 7 days
        21 * 86_400,      // box 5: 21 days
    ]
    public static let maxBox = 5

    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public static func interval(forBox box: Int) -> TimeInterval {
        intervals[min(max(box, 1), maxBox) - 1]
    }

    /// True when the card may be shown at `now`.
    public func isDue(_ state: CardState?, now: Date) -> Bool {
        guard let state else { return true }
        if state.lastCorrectDay == Day(now, calendar: calendar) { return false }
        return state.due <= now
    }

    /// The new state after one answer.
    /// - Parameter lapsedThisSession: the card was answered wrong earlier in the same session.
    ///   A correct answer then counts for today but does not move the card up a box.
    public func apply(correct: Bool, to state: CardState?, now: Date, lapsedThisSession: Bool = false) -> CardState {
        var s = state ?? CardState(box: 0, due: now)
        s.reviews += 1
        s.lastReviewed = now
        if correct {
            s.correct += 1
            let newBox = lapsedThisSession ? max(s.box, 1) : min(s.box + 1, Self.maxBox)
            s.box = newBox
            s.due = now.addingTimeInterval(Self.interval(forBox: newBox))
            s.lastCorrectDay = Day(now, calendar: calendar)
        } else {
            s.box = 1
            s.due = now.addingTimeInterval(Self.interval(forBox: 1))
        }
        return s
    }

    /// Cards to study now: due reviews first (oldest due first, then higher count),
    /// then new cards ordered by count (higher first), at most `newLimit` of them.
    public func dueCards(_ entries: [VocabEntry], states: [String: CardState], now: Date, newLimit: Int) -> [VocabEntry] {
        var reviews: [(VocabEntry, Date)] = []
        var fresh: [VocabEntry] = []
        for e in entries {
            if let st = states[e.word] {
                if isDue(st, now: now) { reviews.append((e, st.due)) }
            } else {
                fresh.append(e)
            }
        }
        reviews.sort { a, b in
            a.1 != b.1 ? a.1 < b.1 : (a.0.count != b.0.count ? a.0.count > b.0.count : a.0.word < b.0.word)
        }
        let orderedNew = fresh.enumerated().sorted { a, b in
            a.element.count != b.element.count ? a.element.count > b.element.count : a.offset < b.offset
        }.map(\.element)
        return reviews.map(\.0) + orderedNew.prefix(max(newLimit, 0))
    }
}
