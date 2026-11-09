import Foundation

/// One step of the alignment between the right spelling and what was typed.
public enum DiffOp: Equatable, Sendable {
    case same(Character)
    case substituted(expected: Character, typed: Character)
    /// A letter of the right spelling that was not typed.
    case missing(Character)
    /// A typed letter that is not in the right spelling.
    case extra(Character)
}

public enum AnswerChecker {
    /// Trims, lowercases and collapses inner spaces.
    public static func normalize(_ s: String) -> String {
        Markdown.collapseWhitespace(s).lowercased()
    }

    public static func isCorrect(expected: String, typed: String) -> Bool {
        let t = normalize(typed)
        guard !t.isEmpty else { return false }
        return normalize(expected) == t
    }

    /// A minimal edit script (Levenshtein) from `typed` to `expected`, in the order of `expected`.
    public static func diff(expected: String, typed: String) -> [DiffOp] {
        let e = Array(normalize(expected))
        let t = Array(normalize(typed))
        let n = e.count, m = t.count
        var d = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { d[i][0] = i }
        for j in 0...m { d[0][j] = j }
        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    let cost = e[i - 1] == t[j - 1] ? 0 : 1
                    d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                }
            }
        }
        var ops: [DiffOp] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && e[i - 1] == t[j - 1] && d[i][j] == d[i - 1][j - 1] {
                ops.append(.same(e[i - 1])); i -= 1; j -= 1
            } else if i > 0 && j > 0 && d[i][j] == d[i - 1][j - 1] + 1 {
                ops.append(.substituted(expected: e[i - 1], typed: t[j - 1])); i -= 1; j -= 1
            } else if i > 0 && d[i][j] == d[i - 1][j] + 1 {
                ops.append(.missing(e[i - 1])); i -= 1
            } else {
                ops.append(.extra(t[j - 1])); j -= 1
            }
        }
        return ops.reversed()
    }

    /// For each character of the normalized right spelling: true when the person got it wrong
    /// (substituted, missing, or an extra letter was typed right before it).
    public static func wrongMask(expected: String, typed: String) -> [Bool] {
        var mask: [Bool] = []
        var pendingExtra = false
        for op in diff(expected: expected, typed: typed) {
            switch op {
            case .same: mask.append(pendingExtra); pendingExtra = false
            case .substituted, .missing: mask.append(true); pendingExtra = false
            case .extra: pendingExtra = true
            }
        }
        if pendingExtra, !mask.isEmpty { mask[mask.count - 1] = true }
        return mask
    }
}

/// The question side of a card: `容量 → c_______ (8)`.
public enum CardPrompt {
    /// First letter, then one `_` per remaining letter. Spaces, hyphens and apostrophes stay.
    public static func mask(_ word: String) -> String {
        var out = ""
        var shownFirst = false
        for ch in word {
            if ch.isLetter || ch.isNumber {
                if shownFirst { out.append("_") } else { out.append(ch); shownFirst = true }
            } else {
                out.append(ch)
            }
        }
        return out
    }

    public static func letterCount(_ word: String) -> Int {
        word.filter { $0.isLetter || $0.isNumber }.count
    }

    public static func text(for entry: VocabEntry) -> String {
        "\(entry.meaning) → \(mask(entry.word)) (\(letterCount(entry.word)))"
    }
}
