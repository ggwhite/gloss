import Foundation

/// What happened after one answer.
public struct AnswerOutcome: Equatable, Sendable {
    public var entry: VocabEntry
    public var typed: String
    public var correct: Bool
    public var diff: [DiffOp]
    public var wrongMask: [Bool]
}

/// One study session: a queue of cards, answer checking, and requeue of wrong cards.
public final class QuizSession {
    /// A wrong card comes back after this many other cards (or at the end).
    public static let requeueGap = 3

    public private(set) var queue: [VocabEntry]
    public private(set) var state: GlossState
    public private(set) var lapsed: Set<String> = []
    public private(set) var answeredCount = 0
    public private(set) var correctCount = 0
    public let scheduler: LeitnerScheduler
    private let now: () -> Date

    public init(cards: [VocabEntry], state: GlossState, scheduler: LeitnerScheduler, now: @escaping () -> Date) {
        self.queue = cards
        self.state = state
        self.scheduler = scheduler
        self.now = now
    }

    public var current: VocabEntry? { queue.first }
    public var remaining: Int { queue.count }
    public var isFinished: Bool { queue.isEmpty }

    /// Checks the answer for the current card and updates the saved state.
    /// A correct card leaves the queue; a wrong card goes back `requeueGap` places later.
    @discardableResult
    public func submit(_ typed: String) -> AnswerOutcome? {
        guard let entry = queue.first else { return nil }
        let t = now()
        let today = Day(t, calendar: scheduler.calendar)
        let ok = AnswerChecker.isCorrect(expected: entry.word, typed: typed)
        let wasNew = state.cards[entry.word] == nil

        state.cards[entry.word] = scheduler.apply(
            correct: ok, to: state.cards[entry.word], now: t, lapsedThisSession: lapsed.contains(entry.word))

        var day = state.stats(for: today)
        day.answered += 1
        if ok { day.correct += 1 }
        if wasNew { day.newIntroduced += 1 }
        state.daily[today.iso] = day
        answeredCount += 1
        if ok { correctCount += 1 }

        queue.removeFirst()
        if !ok {
            lapsed.insert(entry.word)
            queue.insert(entry, at: min(Self.requeueGap, queue.count))
        }
        return AnswerOutcome(
            entry: entry, typed: typed, correct: ok,
            diff: AnswerChecker.diff(expected: entry.word, typed: typed),
            wrongMask: AnswerChecker.wrongMask(expected: entry.word, typed: typed))
    }

    /// Moves the current card to the end without answering it.
    public func skip() {
        guard !queue.isEmpty else { return }
        queue.append(queue.removeFirst())
    }
}
