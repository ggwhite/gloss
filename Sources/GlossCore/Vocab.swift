import Foundation

public enum Deck: String, Codable, CaseIterable, Identifiable, Sendable {
    case spelling
    case usage
    /// New words you looked up: the `## 問過的字` table (| 字 | 中文 | 例句 |) plus words added in Gloss.
    case asked

    public var id: String { rawValue }
    public var headingPrefix: String {
        switch self {
        case .spelling: return "## 拼字"
        case .usage: return "## 用字"
        case .asked: return "## 問過的字"
        }
    }
    public var title: String {
        switch self {
        case .spelling: return "Spelling (拼字)"
        case .usage: return "Word choice (用字)"
        case .asked: return "New words (問過的字)"
        }
    }
}

/// One row of a vocabulary table: `| 正確拼法 | 你打的 | 中文 | 記法 | 次數 |`.
public struct VocabEntry: Equatable, Hashable, Codable, Identifiable, Sendable {
    /// The correct spelling, Markdown removed. This is the answer and the state key.
    public var word: String
    /// What was typed by mistake (may contain `?`).
    public var typed: String
    /// Chinese meaning.
    public var meaning: String
    /// Memory hint.
    public var hint: String
    /// How many times this mistake happened.
    public var count: Int
    public var deck: Deck

    public var id: String { word }

    public init(word: String, typed: String = "", meaning: String = "", hint: String = "", count: Int = 1, deck: Deck = .spelling) {
        self.word = word
        self.typed = typed
        self.meaning = meaning
        self.hint = hint
        self.count = count
        self.deck = deck
    }
}

public enum VocabParser {
    /// Parses every deck in `單字.md`.
    public static func parse(_ text: String) -> [Deck: [VocabEntry]] {
        var out: [Deck: [VocabEntry]] = [:]
        for deck in Deck.allCases {
            out[deck] = parse(text, deck: deck)
        }
        return out
    }

    /// Parses the table under the heading for `deck`. Missing section gives an empty list.
    public static func parse(_ text: String, deck: Deck) -> [VocabEntry] {
        guard let lines = Markdown.section(in: text, headingPrefix: deck.headingPrefix) else { return [] }
        var entries: [VocabEntry] = []
        var seen: [String: Int] = [:]
        var sawHeader = false
        for line in lines {
            guard let cells = Markdown.tableCells(String(line)) else {
                // A blank line or text ends one table; a later table in the section starts with a header again.
                if !line.trimmingCharacters(in: .whitespaces).isEmpty { sawHeader = false }
                continue
            }
            if Markdown.isSeparatorRow(cells) { continue }
            if !sawHeader { sawHeader = true; continue } // header row
            guard let entry = entry(from: cells, deck: deck) else { continue }
            let key = entry.word.lowercased()
            if let i = seen[key] {
                entries[i].count = max(entries[i].count, entry.count)
            } else {
                seen[key] = entries.count
                entries.append(entry)
            }
        }
        return entries
    }

    static func entry(from cells: [String], deck: Deck) -> VocabEntry? {
        func cell(_ i: Int) -> String { i < cells.count ? cells[i] : "" }
        let word = cleanAnswer(cell(0))
        guard !word.isEmpty else { return nil }
        if deck == .asked {
            // | 字 | 中文 | 例句 |: the example sentence is the hint shown after a mistake.
            return VocabEntry(word: word, meaning: Markdown.strip(cell(1)), hint: Markdown.strip(cell(2)), count: 1, deck: deck)
        }
        return VocabEntry(
            word: word,
            typed: Markdown.strip(cell(1)),
            meaning: Markdown.strip(cell(2)),
            hint: Markdown.strip(cell(3)),
            count: parseCount(cell(4)),
            deck: deck
        )
    }

    /// The answer cell: Markdown removed and question marks dropped.
    public static func cleanAnswer(_ raw: String) -> String {
        let stripped = Markdown.strip(raw).replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "？", with: "")
        return Markdown.collapseWhitespace(stripped)
    }

    /// The first run of digits in the cell, or 1 when there is none.
    public static func parseCount(_ raw: String) -> Int {
        let digits = Markdown.strip(raw).drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
        guard let n = Int(digits), n > 0 else { return 1 }
        return n
    }
}
