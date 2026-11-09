import Foundation

/// The JSON that `claude -p` returns for the fix-my-English hotkey.
public struct FixResult: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Hashable, Sendable {
        public var from: String
        public var to: String
        public var why_zh: String
        public var category: String

        public init(from: String, to: String, why_zh: String, category: String) {
            self.from = from
            self.to = to
            self.why_zh = why_zh
            self.category = category
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            from = (try? c.decode(String.self, forKey: .from)) ?? ""
            to = (try? c.decode(String.self, forKey: .to)) ?? ""
            why_zh = (try? c.decode(String.self, forKey: .why_zh)) ?? ""
            category = (try? c.decode(String.self, forKey: .category)) ?? ""
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
        {"fixed": "...", "short": "...", "mistakes": [{"from": "...", "to": "...", "why_zh": "...", "category": "..."}]}
        - fixed: the whole text, corrected, with the same meaning and tone.
        - short: a shorter way a native speaker would say it.
        - mistakes: one item per grammar, spelling or word-choice error; [] when there are none.
        - why_zh: one short explanation in Traditional Chinese.
        - category: one of \(MistakeCategory.known.joined(separator: ", ")).
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
