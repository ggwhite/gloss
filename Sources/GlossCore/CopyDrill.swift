import Foundation

/// After a wrong answer: type the right spelling a few more times, with the answer on screen.
/// It only helps memory; the card's schedule was already set by the wrong answer.
public struct CopyDrill: Equatable, Sendable {
    public enum Result: Equatable, Sendable {
        /// A right copy that still leaves more to do.
        case counted
        /// The last right copy.
        case finished
        /// A copy with a mistake; it does not count.
        case wrong
        /// Nothing typed (Enter on an empty field skips the drill).
        case empty
    }

    /// Default number of copies. See MECHANICS.md.
    public static let defaultReps = 3
    public static let maxReps = 5

    public let word: String
    public let required: Int
    public private(set) var done = 0
    public private(set) var misses = 0

    public init(word: String, required: Int) {
        self.word = word
        self.required = max(1, required)
    }

    public var isFinished: Bool { done >= required }

    public mutating func submit(_ typed: String) -> Result {
        guard !AnswerChecker.normalize(typed).isEmpty else { return .empty }
        guard !isFinished else { return .finished }
        if AnswerChecker.isCorrect(expected: word, typed: typed) {
            done += 1
            return isFinished ? .finished : .counted
        }
        misses += 1
        return .wrong
    }
}

extension CardPrompt {
    /// For the copy drill: whether each typed letter matches the right letter in its box
    /// (nil for boxes not typed yet and for spaces or hyphens).
    public static func letterMatches(for word: String, typed: String) -> [Bool?] {
        let (slots, _) = slots(for: word, typed: typed)
        return zip(slots, word).map { slot, expected in
            if case .typed(let c) = slot { return Character(c.lowercased()) == Character(expected.lowercased()) }
            return nil
        }
    }
}
