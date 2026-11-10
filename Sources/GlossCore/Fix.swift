import Foundation

/// The JSON that `claude -p` returns for the fix-my-English hotkey.
public struct FixResult: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Hashable, Sendable {
        public var from: String
        public var to: String
        public var why_zh: String
        public var category: String
        /// 拼字/用字 only: short Chinese meaning of the correct word (the 中文 column of 單字.md).
        public var meaning: String
        /// 拼字/用字 only: short Chinese memory hint (the 記法 column of 單字.md).
        public var hint: String
        /// True when the word is a proper noun; it is not added to 單字.md.
        public var proper_noun: Bool

        public init(from: String, to: String, why_zh: String, category: String,
                    meaning: String = "", hint: String = "", proper_noun: Bool = false) {
            self.from = from
            self.to = to
            self.why_zh = why_zh
            self.category = category
            self.meaning = meaning
            self.hint = hint
            self.proper_noun = proper_noun
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            from = (try? c.decode(String.self, forKey: .from)) ?? ""
            to = (try? c.decode(String.self, forKey: .to)) ?? ""
            why_zh = (try? c.decode(String.self, forKey: .why_zh)) ?? ""
            category = (try? c.decode(String.self, forKey: .category)) ?? ""
            meaning = (try? c.decode(String.self, forKey: .meaning)) ?? ""
            hint = (try? c.decode(String.self, forKey: .hint)) ?? ""
            proper_noun = (try? c.decode(Bool.self, forKey: .proper_noun)) ?? false
        }
    }

    public var fixed: String
    public var short: String
    public var mistakes: [Item]

    public init(fixed: String, short: String, mistakes: [Item]) {
        self.fixed = fixed
        self.short = short
        self.mistakes = mistakes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fixed = try c.decode(String.self, forKey: .fixed)
        short = (try? c.decode(String.self, forKey: .short)) ?? fixed
        mistakes = (try? c.decode([Item].self, forKey: .mistakes)) ?? []
    }
}

public enum FixParseError: Error, Equatable, LocalizedError {
    case noJSON
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .noJSON: return "Claude did not return JSON."
        case .invalid(let why): return "Claude returned JSON in an unexpected shape: \(why)"
        }
    }
}

public enum FixPrompt {
    public static let timeout: TimeInterval = 30

    public static func build(for text: String) -> String {
        """
        You are an English writing coach for a Chinese-speaking software engineer.
        Fix the English text between the <text> tags. Reply with ONLY one JSON object and nothing else \
        (no Markdown fences, no comments), in exactly this shape:
        {"fixed": "...", "short": "...", "mistakes": [{"from": "...", "to": "...", "why_zh": "...", "category": "...", "meaning": "...", "hint": "...", "proper_noun": false}]}
        - fixed: the whole text, corrected, with the same meaning and tone.
        - short: a shorter way a native speaker would say it.
        - mistakes: one item per grammar, spelling or word-choice error; [] when there are none. \
        Do not list mistakes that are only capitalization or punctuation.
        - why_zh: one short explanation in Traditional Chinese.
        - category: exactly one of \(MistakeCategory.known.joined(separator: ", ")) (no # sign).
        - For 拼字 and 用字: from is only the wrong word and to is only the right word (not the whole sentence); \
        meaning is the right word's short meaning in Traditional Chinese; \
        hint is a short memory tip (記法) in Traditional Chinese, such as which letters are easy to miss; \
        proper_noun is true when the word is a name of a person, product, company or place.
        - For other categories: meaning and hint are "" and proper_noun is false.
        <text>
        \(text)
        </text>
        """
    }

    /// Finds the JSON object in Claude's reply (it may be wrapped in fences or text) and decodes it.
    public static func parse(_ output: String) throws -> FixResult {
        guard let start = output.firstIndex(of: "{"), let end = output.lastIndex(of: "}"), start < end else {
            throw FixParseError.noJSON
        }
        let json = String(output[start...end])
        do {
            return try JSONDecoder().decode(FixResult.self, from: Data(json.utf8))
        } catch {
            throw FixParseError.invalid(String(describing: error))
        }
    }
}
