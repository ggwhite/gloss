import Foundation

/// A meaning and an example sentence kept for a word whose table has no example column
/// (`## 拼字`, `## 用字`). Written by Claude on request; stored in Gloss, never in the vault.
public struct WordNote: Codable, Equatable, Sendable {
    public var meaning: String
    public var example: String
    public var updated: Date

    public init(meaning: String, example: String, updated: Date = Date()) {
        self.meaning = meaning
        self.example = example
        self.updated = updated
    }
}

/// `~/Library/Application Support/Gloss/word-notes.json`, keyed by the word in lower case.
public struct WordNoteStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public static var defaultURL: URL {
        StateStore.defaultURL.deletingLastPathComponent().appendingPathComponent("word-notes.json")
    }

    public func load() -> [String: WordNote] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return (try? d.decode([String: WordNote].self, from: data)) ?? [:]
    }

    /// Adds or replaces notes; returns everything stored.
    @discardableResult
    public func merge(_ notes: [String: WordNote]) throws -> [String: WordNote] {
        var all = load()
        for (k, v) in notes { all[k.lowercased()] = v }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601
        try e.encode(all).write(to: url, options: .atomic)
        return all
    }
}

/// One word as the Words page shows it: from its deck, with an example from the table or from Gloss's notes.
public struct WordInfo: Equatable, Sendable, Identifiable {
    public var entry: VocabEntry
    public var meaning: String
    public var example: String
    public var id: String { entry.word.lowercased() }

    /// The memory hint of a 拼字 / 用字 row (the 問過的字 hint is its example).
    public var hint: String { entry.deck == .asked ? "" : entry.hint }

    public static func build(_ entries: [VocabEntry], notes: [String: WordNote]) -> [WordInfo] {
        entries.map { e in
            let note = notes[e.word.lowercased()]
            let meaning = e.meaning.isEmpty ? (note?.meaning ?? "") : e.meaning
            let example = e.deck == .asked && !e.hint.isEmpty ? e.hint : (note?.example ?? "")
            return WordInfo(entry: e, meaning: meaning, example: example)
        }
    }
}

/// Asking Claude for examples (and missing meanings) for many words at once.
public enum ExampleBatch {
    /// Words per question. See MECHANICS.md.
    public static let size = 20

    public static func prompt(for words: [(word: String, meaning: String)]) -> String {
        let list = words.map { w in w.meaning.isEmpty ? "- \(w.word)" : "- \(w.word) (\(w.meaning))" }.joined(separator: "\n")
        return """
        For each English word below (a Chinese-speaking software engineer is learning them), write one short,
        natural example sentence about everyday or engineering work, and a short meaning in Traditional Chinese.
        Reply with ONLY one JSON object and nothing else (no Markdown fences):
        {"items": [{"word": "...", "meaning_zh": "...", "example": "..."}]}
        Keep each word exactly as written. One item per word, same order.
        \(list)
        """
    }

    struct Reply: Decodable {
        struct Item: Decodable { var word: String; var meaning_zh: String?; var example: String? }
        var items: [Item]
    }

    /// Notes for the asked words only (keyed in lower case); anything else in the reply is ignored.
    public static func parse(_ output: String, asked: [String], now: Date = Date()) throws -> [String: WordNote] {
        guard let s = output.firstIndex(of: "{"), let e = output.lastIndex(of: "}"), s < e else { throw FixParseError.noJSON }
        let reply: Reply
        do {
            reply = try JSONDecoder().decode(Reply.self, from: Data(String(output[s...e]).utf8))
        } catch {
            throw FixParseError.invalid(String(describing: error))
        }
        let wanted = Set(asked.map { $0.lowercased() })
        var out: [String: WordNote] = [:]
        for item in reply.items {
            let key = item.word.trimmingCharacters(in: .whitespaces).lowercased()
            let example = Markdown.collapseWhitespace(item.example ?? "")
            guard wanted.contains(key), !example.isEmpty else { continue }
            out[key] = WordNote(meaning: Markdown.collapseWhitespace(item.meaning_zh ?? ""), example: example, updated: now)
        }
        return out
    }

    /// Splits the words that still need an example into batches.
    public static func batches(_ words: [WordInfo]) -> [[WordInfo]] {
        let missing = words.filter { $0.example.isEmpty }
        return stride(from: 0, to: missing.count, by: size).map { Array(missing[$0..<min($0 + size, missing.count)]) }
    }
}
