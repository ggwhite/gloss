import Foundation

/// Small helpers for the subset of Markdown that appears in the vault tables.
public enum Markdown {
    /// Removes emphasis markers, code ticks, strike-through, links and HTML line breaks.
    public static func strip(_ text: String) -> String {
        var s = text
        for br in ["<br>", "<br/>", "<br />"] { s = s.replacingOccurrences(of: br, with: " ") }
        s = s.replacingOccurrences(of: "\\|", with: "|")
        if let re = try? NSRegularExpression(pattern: #"\[([^\]]*)\]\([^)]*\)"#) {
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1")
        }
        for marker in ["**", "__", "~~", "`"] {
            s = s.replacingOccurrences(of: marker, with: "")
        }
        if let re = try? NSRegularExpression(pattern: #"(?<![\w*])[*_]([^*_\s][^*_]*?)[*_](?![\w*])"#) {
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1")
        }
        return collapseWhitespace(s)
    }

    public static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Splits one table row into its cells. Escaped pipes (`\|`) and pipes inside backticks stay in a cell.
    /// Returns nil when the line is not a table row.
    public static func tableCells(_ line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") else { return nil }
        var cells: [String] = []
        var current = ""
        var escaped = false
        var inCode = false
        for ch in trimmed.dropFirst() {
            if escaped {
                current.append(ch == "|" ? "|" : "\\\(ch)")
                escaped = false
                continue
            }
            switch ch {
            case "\\": escaped = true
            case "`": inCode.toggle(); current.append(ch)
            case "|" where !inCode:
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            default: current.append(ch)
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { cells.append(rest) }
        return cells
    }

    /// True for the `|---|:---:|` line under a table header.
    public static func isSeparatorRow(_ cells: [String]) -> Bool {
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            return !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" } && c.contains("-")
        }
    }

    /// The lines of the first level-2 section whose heading starts with `prefix` (e.g. `## 拼字`).
    /// The section ends at the next level-1 or level-2 heading.
    public static func section(in text: String, headingPrefix prefix: String) -> [Substring]? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }) else {
            return nil
        }
        var out: [Substring] = []
        for line in lines[(start + 1)...] {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("## ") || t.hasPrefix("# ") || t == "##" { break }
            out.append(line)
        }
        return out
    }
}
