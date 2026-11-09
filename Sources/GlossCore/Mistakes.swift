import Foundation

/// One line of a daily `錯誤紀錄/YYYY-MM-DD.md` file:
/// ``- `original` → `fix` — 中文說明 #類別``
public struct Mistake: Equatable, Hashable, Sendable {
    public var day: Day?
    public var original: String
    public var fix: String
    public var explanation: String
    public var categories: [String]

    public init(day: Day?, original: String, fix: String, explanation: String, categories: [String]) {
        self.day = day
        self.original = original
        self.fix = fix
        self.explanation = explanation
        self.categories = categories
    }
}

public enum MistakeCategory {
    public static let known = ["冠詞", "動詞形式", "單複數", "拼字", "用字", "介系詞", "句型"]
}

public enum MistakeParser {
    /// Parses every mistake line in a file. Lines that do not match are skipped.
    public static func parse(_ text: String, day: Day?) -> [Mistake] {
        text.split(separator: "\n").compactMap { parseLine(String($0), day: day) }
    }

    /// The day from a file name such as `2026-01-31.md`.
    public static func day(fromFileName name: String) -> Day? {
        guard name.hasSuffix(".md") else { return nil }
        return Day(iso: String(name.dropLast(3)))
    }

    public static func parseLine(_ line: String, day: Day?) -> Mistake? {
        var s = Substring(line.trimmingCharacters(in: .whitespaces))
        guard s.hasPrefix("- ") || s.hasPrefix("* ") else { return nil }
        s = s.dropFirst(2)
        guard let arrow = s.range(of: "→") ?? s.range(of: "->") else { return nil }
        let left = s[..<arrow.lowerBound]
        let right = s[arrow.upperBound...]

        guard let original = firstCode(in: left) ?? nonEmpty(Markdown.strip(String(left))) else { return nil }

        // Split the fix from the explanation at the dash.
        var fixPart = right
        var explanation = Substring("")
        for dash in [" — ", " – ", " -- ", "—"] {
            if let r = right.range(of: dash) {
                fixPart = right[..<r.lowerBound]
                explanation = right[r.upperBound...]
                break
            }
        }
        guard let fix = firstCode(in: fixPart) ?? nonEmpty(Markdown.strip(String(fixPart))) else { return nil }

        let (text, tags) = splitTags(String(explanation))
        return Mistake(day: day, original: original, fix: fix, explanation: text, categories: tags)
    }

    /// The text inside the first pair of backticks.
    static func firstCode(in s: Substring) -> String? {
        guard let open = s.firstIndex(of: "`") else { return nil }
        let after = s[s.index(after: open)...]
        guard let close = after.firstIndex(of: "`") else { return nil }
        return nonEmpty(String(after[..<close]))
    }

    static func nonEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }

    /// Removes `#tag` words and returns them separately.
    static func splitTags(_ s: String) -> (String, [String]) {
        var words: [String] = []
        var tags: [String] = []
        for word in s.split(separator: " ") {
            if word.hasPrefix("#"), word.count > 1 {
                tags.append(String(word.dropFirst()))
            } else {
                words.append(String(word))
            }
        }
        return (words.joined(separator: " ").trimmingCharacters(in: .whitespaces), tags)
    }
}
