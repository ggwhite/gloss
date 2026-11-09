import Foundation

/// The overall state shown at the top of the menu: "English Health: Good".
public enum EnglishHealth: String, Equatable, Sendable {
    case gettingStarted = "Getting started"
    case good = "Good"
    case fair = "Fair"
    case needsPractice = "Needs practice"
}

/// What the menu suggests doing next.
public struct Recommendation: Equatable, Sendable {
    public enum Action: Equatable, Sendable { case quiz, practice, stats, fix }
    public var symbol: String
    public var title: String
    public var detail: String
    public var actionTitle: String
    public var action: Action
}

public enum Overview {
    /// Fewest answers in 7 days before a health grade is given. See MECHANICS.md.
    public static let minAnswersForHealth = 5
    /// 7-day accuracy for "Good" and "Fair".
    public static let goodAccuracy = 0.8
    public static let fairAccuracy = 0.6
    /// More due cards than this keeps the grade below "Good".
    public static let maxDueForGood = 20

    public static func health(answered: Int, correct: Int, due: Int) -> EnglishHealth {
        guard answered >= minAnswersForHealth else { return .gettingStarted }
        let a = Double(correct) / Double(answered)
        if a >= goodAccuracy && due <= maxDueForGood { return .good }
        if a >= fairAccuracy { return .fair }
        return .needsPractice
    }

    /// Days in a row with at least one answer. The current streak may end today or yesterday.
    public static func streak(_ state: GlossState, today: Day, calendar: Calendar) -> (current: Int, best: Int) {
        let active = Set(state.daily.filter { $0.value.answered > 0 }.keys)
        var current = 0
        var day = active.contains(today.iso) ? today : today.adding(days: -1, calendar: calendar)
        while active.contains(day.iso) {
            current += 1
            day = day.adding(days: -1, calendar: calendar)
        }
        var best = 0, run = 0
        var previous: Day?
        for iso in active.sorted() {
            guard let d = Day(iso: iso) else { continue }
            if let p = previous, p.adding(days: 1, calendar: calendar) == d { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = d
        }
        return (current, max(best, current))
    }

    /// Cards per box: index 0 is new (never answered), 1...5 are the Leitner boxes.
    public static func boxCounts(_ entries: [VocabEntry], states: [String: CardState]) -> [Int] {
        var counts = Array(repeating: 0, count: LeitnerScheduler.maxBox + 1)
        for e in entries {
            let box = states[e.word]?.box ?? 0
            counts[min(max(box, 0), LeitnerScheduler.maxBox)] += 1
        }
        return counts
    }

    /// A 7-day category needs this many mistakes before it beats extra practice as the suggestion.
    public static let categoryAlertCount = 3

    /// The next thing to do: due cards, then a category with many mistakes this week, then extra practice
    /// (when there are cards), then the fixer.
    public static func recommend(due: [VocabEntry], week: [CategoryCount], fixShortcut: String,
                                 canPractise: Bool = false) -> Recommendation {
        if let first = due.max(by: { $0.count < $1.count }) {
            let n = due.count
            let meaning = first.meaning.isEmpty ? "the first card" : "“\(first.meaning)”"
            return Recommendation(
                symbol: "brain.head.profile",
                title: "Practise \(n) card\(n == 1 ? "" : "s")",
                detail: "Start with \(meaning) — you have missed it \(first.count)×. It takes about \(max(1, (n * 10 + 59) / 60)) min.",
                actionTitle: "Start Quiz",
                action: .quiz)
        }
        let worst = week.filter { $0.count > 0 }.max(by: { $0.count < $1.count })
        if canPractise, (worst?.count ?? 0) < categoryAlertCount {
            return Recommendation(
                symbol: "flame.fill",
                title: "Keep practising",
                detail: "Today's reviews are done. Try the \(Practice.roundSize) words you miss most — it won't change your schedule.",
                actionTitle: "Practise",
                action: .practice)
        }
        if let worst {
            return Recommendation(
                symbol: "exclamationmark.bubble",
                title: "Watch your #\(worst.category)",
                detail: "\(worst.count) \(worst.category) mistake\(worst.count == 1 ? "" : "s") in the last 7 days — more than any other kind.",
                actionTitle: "Open Stats",
                action: .stats)
        }
        return Recommendation(
            symbol: "wand.and.stars",
            title: "All caught up",
            detail: "Nothing is due. Select some English in any app and press \(fixShortcut) to check it.",
            actionTitle: "Fix My English",
            action: .fix)
    }
}
