import Foundation

/// A word added by hand in Gloss (the "Add Word" page).
public struct NewWord: Codable, Equatable, Sendable {
    public var word: String
    public var meaning: String
    public var example: String
    public var added: Date

    public init(word: String, meaning: String, example: String = "", added: Date = Date()) {
        self.word = word
        self.meaning = meaning
        self.example = example
        self.added = added
    }

    public var entry: VocabEntry {
        VocabEntry(word: word, meaning: meaning, hint: example, count: 1, deck: .asked)
    }
}

/// Words added in Gloss while it may not write to the vault: `~/Library/Application Support/Gloss/words.json`.
public struct NewWordStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public static var defaultURL: URL {
        StateStore.defaultURL.deletingLastPathComponent().appendingPathComponent("words.json")
    }

    public func load() -> [NewWord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return (try? d.decode([NewWord].self, from: data)) ?? []
    }

    /// Adds the word, or updates its meaning and example when it is already there (any case).
    @discardableResult
    public func add(_ w: NewWord) throws -> [NewWord] {
        var all = load()
        if let i = all.firstIndex(where: { $0.word.lowercased() == w.word.lowercased() }) {
            all[i].meaning = w.meaning
            all[i].example = w.example
        } else {
            all.append(w)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601
        try e.encode(all).write(to: url, options: .atomic)
        return all
    }
}

/// Adds a row to the `## 問過的字` table of 單字.md (| 字 | 中文 | 例句 |). Anything unexpected about the
/// table (missing, other columns) refuses the change, so the note is never written in a wrong shape.
public enum AskedTable {
    public enum Failure: Error, Equatable, Sendable {
        case noSection
        case unexpectedColumns([String])
        case alreadyThere
    }

    public static let columns = ["字", "中文", "例句"]

    public static func add(word: String, meaning: String, example: String, to text: String) -> Result<String, Failure> {
        var lines = text.components(separatedBy: "\n")
        guard let head = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(Deck.asked.headingPrefix) }) else {
            return .failure(.noSection)
        }
        // The table: the first run of "|" lines after the heading, before the next heading.
        var first: Int?, last: Int?
        var i = head + 1
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("#") { break }
            if t.hasPrefix("|") { if first == nil { first = i }; last = i } else if first != nil { break }
            i += 1
        }
        guard let f = first, let l = last, l >= f + 1 else { return .failure(.noSection) }
        let header = Markdown.tableCells(lines[f]) ?? []
        guard header == columns else { return .failure(.unexpectedColumns(header)) }
        let key = word.trimmingCharacters(in: .whitespaces).lowercased()
        for row in lines[(f + 2)...l] {
            if let c = Markdown.tableCells(row), let w = c.first, VocabParser.cleanAnswer(w).lowercased() == key {
                return .failure(.alreadyThere)
            }
        }
        func cell(_ s: String) -> String {
            s.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
        }
        lines.insert("| \(cell(word)) | \(cell(meaning)) | \(cell(example)) |", at: l + 1)
        return .success(lines.joined(separator: "\n"))
    }
}

/// The JSON `claude -p` returns when looking up a new word.
public struct WordLookup: Codable, Equatable, Sendable {
    public var word: String
    public var meaning_zh: String
    public var example: String

    public init(word: String, meaning_zh: String, example: String) {
        self.word = word
        self.meaning_zh = meaning_zh
        self.example = example
    }

    public static func prompt(for word: String) -> String {
        """
        A Chinese-speaking software engineer met an English word they don't know: "\(word)".
        Reply with ONLY one JSON object and nothing else (no Markdown fences):
        {"word": "...", "meaning_zh": "...", "example": "..."}
        - word: the correct spelling (fix it if it is misspelled; keep the base form).
        - meaning_zh: a short meaning in Traditional Chinese (several meanings separated by 、).
        - example: one short, natural English sentence using the word, about everyday or engineering work.
        """
    }

    public static func parse(_ output: String) throws -> WordLookup {
        guard let s = output.firstIndex(of: "{"), let e = output.lastIndex(of: "}"), s < e else { throw FixParseError.noJSON }
        do {
            return try JSONDecoder().decode(WordLookup.self, from: Data(String(output[s...e]).utf8))
        } catch {
            throw FixParseError.invalid(String(describing: error))
        }
    }
}
