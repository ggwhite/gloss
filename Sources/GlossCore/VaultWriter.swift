import Foundation

/// What saving one Fix My English result to the vault did.
public struct VaultSaveReport: Equatable, Sendable {
    /// Lines appended to today's 錯誤紀錄 file.
    public var saved = 0
    /// Lines already in today's file (or twice in the same result), so not written again.
    public var duplicates = 0
    /// Mistakes left out: capitalization or punctuation only, or a category outside `MistakeCategory.known`.
    public var skipped = 0
    /// Rows of 單字.md that were changed or added.
    public var vocabChanged = 0
    public var warnings: [String] = []

    public init() {}

    /// The status line shown in the Fix My English panel.
    public var summary: String {
        var s: String
        if saved > 0 {
            s = "Saved \(saved) mistake\(saved == 1 ? "" : "s") to \(Vault.mistakesFolder)"
            if vocabChanged > 0 { s += " · updated \(vocabChanged) word\(vocabChanged == 1 ? "" : "s") in \(Vault.vocabFile)" }
        } else if duplicates > 0 {
            s = "Already saved to \(Vault.mistakesFolder)"
        } else {
            s = "Nothing to save to \(Vault.mistakesFolder)"
        }
        for w in warnings { s += " — \(w)" }
        return s
    }
}

/// One line of `錯誤紀錄/YYYY-MM-DD.md`, made from a Fix My English mistake.
public enum FixLog {
    /// ``- `original` → `fix` — 中文說明 #類別``, or nil when the mistake is not saved.
    public static func line(for item: FixResult.Item) -> String? {
        guard let category = category(of: item) else { return nil }
        let from = clean(item.from).replacingOccurrences(of: "`", with: "'")
        let to = clean(item.to).replacingOccurrences(of: "`", with: "'")
        guard !from.isEmpty, !to.isEmpty, !isCaseOrPunctuationOnly(from, to) else { return nil }
        let why = clean(item.why_zh)
        return "- `\(from)` → `\(to)` — \(why.isEmpty ? "" : why + " ")#\(category)"
    }

    /// The category without `#`, when it is one of `MistakeCategory.known`.
    public static func category(of item: FixResult.Item) -> String? {
        var c = item.category.trimmingCharacters(in: .whitespacesAndNewlines)
        while c.hasPrefix("#") { c.removeFirst() }
        return MistakeCategory.known.contains(c) ? c : nil
    }

    /// True when the two texts differ only in upper/lower case, punctuation or spacing (or not at all).
    /// Apostrophes are not punctuation here: `its` → `it's` is a real (#拼字) mistake. `’` counts as `'`.
    public static func isCaseOrPunctuationOnly(_ a: String, _ b: String) -> Bool {
        func norm(_ s: String) -> String {
            let kept = s.lowercased().replacingOccurrences(of: "’", with: "'").unicodeScalars.filter {
                $0 == "'" || (!CharacterSet.punctuationCharacters.contains($0) && !CharacterSet.symbols.contains($0))
            }
            return Markdown.collapseWhitespace(String(String.UnicodeScalarView(kept)))
        }
        return norm(a) == norm(b)
    }

    static func clean(_ s: String) -> String { Markdown.collapseWhitespace(s) }
}

/// Edits the vocabulary tables of 單字.md line by line. Only the lines it targets change.
public enum VocabEditor {
    public struct Change: Equatable, Sendable {
        /// The correct spelling (正確拼法 / 該用).
        public var word: String
        /// What was typed (你打的 / 你用的).
        public var typed: String
        public var meaning: String
        public var hint: String
        public var deck: Deck

        public init(word: String, typed: String, meaning: String, hint: String, deck: Deck) {
            self.word = word
            self.typed = typed
            self.meaning = meaning
            self.hint = hint
            self.deck = deck
        }
    }

    public struct Failure: Error, Equatable, Sendable {
        public var message: String
    }

    /// Applies every change, or none: any problem returns a failure and the text must not be written.
    public static func apply(_ changes: [Change], to text: String) -> Result<String, Failure> {
        var lines = text.components(separatedBy: "\n")
        for change in changes {
            if let failure = apply(change, to: &lines) { return .failure(failure) }
        }
        return .success(lines.joined(separator: "\n"))
    }

    private struct Table { var header: Int; var rows: [Int] }

    private static func apply(_ change: Change, to lines: inout [String]) -> Failure? {
        let prefix = change.deck.headingPrefix
        let headings = lines.indices.filter { lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }
        guard let start = headings.first else { return Failure(message: "no “\(prefix)” heading in \(Vault.vocabFile)") }
        guard headings.count == 1 else { return Failure(message: "more than one “\(prefix)” heading in \(Vault.vocabFile)") }
        var end = start + 1
        while end < lines.count {
            let t = lines[end].trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("## ") || t.hasPrefix("# ") || t == "##" { break }
            end += 1
        }

        // Runs of consecutive table rows; each must be header + separator + rows.
        var tables: [Table] = []
        var i = start + 1
        while i < end {
            guard Markdown.tableCells(body(lines[i])) != nil else { i += 1; continue }
            var run: [Int] = []
            while i < end, Markdown.tableCells(body(lines[i])) != nil { run.append(i); i += 1 }
            guard run.count >= 2, let sep = Markdown.tableCells(body(lines[run[1]])), Markdown.isSeparatorRow(sep),
                  Markdown.tableCells(body(lines[run[0]]))?.count == 5 else {
                return Failure(message: "the table under “\(prefix)” does not have the 5 expected columns")
            }
            tables.append(Table(header: run[0], rows: Array(run.dropFirst(2))))
        }
        guard !tables.isEmpty else { return Failure(message: "no table under “\(prefix)” in \(Vault.vocabFile)") }

        let key = VocabParser.cleanAnswer(change.word).lowercased()
        guard !key.isEmpty else { return Failure(message: "empty word") }
        let matches = tables.flatMap(\.rows).filter { row in
            guard let cells = Markdown.tableCells(body(lines[row])), let first = cells.first else { return false }
            return VocabParser.cleanAnswer(first).lowercased() == key
        }
        if matches.count > 1 {
            return Failure(message: "“\(change.word)” is in more than one row under “\(prefix)”")
        }
        if let row = matches.first {
            guard let edited = edit(lines[row], typed: change.typed, word: change.word) else {
                return Failure(message: "could not read the row for “\(change.word)” under “\(prefix)”")
            }
            lines[row] = edited
            return nil
        }
        guard tables.count == 1, let table = tables.first else {
            return Failure(message: "more than one table under “\(prefix)”, not sure where to add “\(change.word)”")
        }
        let last = table.rows.last ?? table.header + 1
        let cr = lines[last].hasSuffix("\r") ? "\r" : ""
        let row = "| \(escape(change.word)) | \(escape(change.typed)) | \(escape(change.meaning)) | \(escape(change.hint)) | 1 |"
        lines.insert(row + cr, at: last + 1)
        return nil
    }

    /// The line without a trailing `\r` (CRLF files).
    private static func body(_ line: String) -> String {
        line.hasSuffix("\r") ? String(line.dropLast()) : line
    }

    /// Adds 1 to 次數 and adds `typed` to 你打的 when it is not listed yet. Nil when the row has fewer than 5 cells.
    static func edit(_ line: String, typed: String, word: String) -> String? {
        var s = line
        guard cellRanges(s).count >= 5 else { return nil }

        // 次數: bump the first number, or write one.
        let countRange = content(of: cellRanges(s)[4], in: s)
        let countText = s[countRange]
        if let d = countText.firstIndex(where: \.isNumber) {
            let digits = countText[d...].prefix(while: \.isNumber)
            let n = max(Int(digits) ?? 1, 1)
            s.replaceSubrange(digits.startIndex..<digits.endIndex, with: String(n + 1))
        } else {
            replace(cellRanges(s)[4], in: &s, with: String(VocabParser.parseCount(String(countText)) + 1))
        }

        // 你打的: append the new wrong spelling.
        let t = Markdown.collapseWhitespace(typed)
        if !t.isEmpty, t.lowercased() != Markdown.collapseWhitespace(word).lowercased() {
            let typedRange = content(of: cellRanges(s)[1], in: s)
            let listed = Markdown.strip(String(s[typedRange]))
                .split(whereSeparator: { ",，、/".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            if !listed.contains(t.lowercased()) {
                let old = String(s[typedRange])
                replace(cellRanges(s)[1], in: &s, with: old.isEmpty ? escape(t) : old + ", " + escape(t))
            }
        }
        return s
    }

    /// Replaces the text of a cell, keeping the spaces around it (an empty cell gets one space each side).
    private static func replace(_ cell: Range<String.Index>, in s: inout String, with text: String) {
        let c = content(of: cell, in: s)
        if c.isEmpty {
            s.replaceSubrange(cell, with: " \(text) ")
        } else {
            s.replaceSubrange(c, with: text)
        }
    }

    /// The cell without its surrounding spaces.
    private static func content(of cell: Range<String.Index>, in s: String) -> Range<String.Index> {
        var lo = cell.lowerBound, hi = cell.upperBound
        while lo < hi, s[lo].isWhitespace { lo = s.index(after: lo) }
        while hi > lo, s[s.index(before: hi)].isWhitespace { hi = s.index(before: hi) }
        return lo..<hi
    }

    /// The ranges between cell pipes, with the same rules as `Markdown.tableCells`
    /// (escaped pipes and pipes inside backticks stay in a cell).
    static func cellRanges(_ line: String) -> [Range<String.Index>] {
        guard let first = line.firstIndex(where: { !$0.isWhitespace }), line[first] == "|" else { return [] }
        var ranges: [Range<String.Index>] = []
        var cellStart = line.index(after: first)
        var escaped = false, inCode = false
        var i = cellStart
        while i < line.endIndex {
            let ch = line[i]
            if escaped {
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == "`" {
                inCode.toggle()
            } else if ch == "|", !inCode {
                ranges.append(cellStart..<i)
                cellStart = line.index(after: i)
            }
            i = line.index(after: i)
        }
        if !line[cellStart...].allSatisfy(\.isWhitespace) { ranges.append(cellStart..<line.endIndex) }
        return ranges
    }

    static func escape(_ s: String) -> String {
        Markdown.collapseWhitespace(s).replacingOccurrences(of: "|", with: "\\|")
    }
}

/// Writes Fix My English mistakes into the vault (only when the setting is on).
/// 錯誤紀錄 is append-only; 單字.md is changed line by line and replaced atomically.
public enum VaultWriter {
    @discardableResult
    public static func save(_ result: FixResult, root: URL, day: Day) -> VaultSaveReport {
        var report = VaultSaveReport()
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            report.warnings.append("vault folder not found: \(root.path)")
            return report
        }
        let folder = root.appendingPathComponent(Vault.mistakesFolder).resolvingSymlinksInPath()
        let logURL = folder.appendingPathComponent("\(day.iso).md")

        let existing = (try? Data(contentsOf: logURL)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        var present = Set(existing.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        var fresh: [(FixResult.Item, String)] = []
        for item in result.mistakes {
            guard let line = FixLog.line(for: item) else { report.skipped += 1; continue }
            if present.contains(line) { report.duplicates += 1; continue }
            present.insert(line)
            fresh.append((item, line))
        }
        guard !fresh.isEmpty else { return report }

        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try append(fresh.map(\.1), to: logURL)
            report.saved = fresh.count
        } catch {
            report.warnings.append("could not write \(Vault.mistakesFolder)/\(logURL.lastPathComponent): \(error.localizedDescription)")
            return report
        }

        // Only mistakes written just now touch 單字.md, so the same result never counts twice.
        let changes: [VocabEditor.Change] = fresh.compactMap { item, _ in
            guard !item.proper_noun else { return nil }
            let deck: Deck
            switch FixLog.category(of: item) {
            case "拼字": deck = .spelling
            case "用字": deck = .usage
            default: return nil
            }
            return VocabEditor.Change(word: FixLog.clean(item.to), typed: FixLog.clean(item.from),
                                      meaning: item.meaning, hint: item.hint, deck: deck)
        }
        guard !changes.isEmpty else { return report }

        let vocabURL = root.appendingPathComponent(Vault.vocabFile).resolvingSymlinksInPath()
        // Re-read right before writing.
        guard let data = try? Data(contentsOf: vocabURL) else {
            report.warnings.append("\(Vault.vocabFile) not changed: could not read it")
            return report
        }
        let text = String(decoding: data, as: UTF8.self)
        guard Data(text.utf8) == data else {
            report.warnings.append("\(Vault.vocabFile) not changed: it is not valid UTF-8")
            return report
        }
        switch VocabEditor.apply(changes, to: text) {
        case .failure(let f):
            report.warnings.append("\(Vault.vocabFile) not changed: \(f.message)")
        case .success(let updated):
            do {
                if updated != text { try replaceAtomically(vocabURL, with: Data(updated.utf8)) }
                report.vocabChanged = changes.count
            } catch {
                report.warnings.append("\(Vault.vocabFile) not changed: \(error.localizedDescription)")
            }
        }
        return report
    }

    /// Opens the file with O_APPEND (creating it if missing), so every write lands at the true end even when
    /// another program appends at the same time. Adds a newline first when the file does not end with one.
    /// Never truncates.
    static func append(_ lines: [String], to url: URL) throws {
        let fd = open(url.path, O_RDWR | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var out = Data()
        let end = try handle.seekToEnd()
        if end > 0 {
            // Reads go through the offset; writes always go to the end because of O_APPEND.
            try handle.seek(toOffset: end - 1)
            if try handle.read(upToCount: 1) != Data([0x0A]) { out.append(0x0A) }
        }
        out.append(Data((lines.joined(separator: "\n") + "\n").utf8))
        try handle.write(contentsOf: out)
    }

    /// Writes a temp file in the same folder, then renames it over the target.
    static func replaceAtomically(_ url: URL, with data: Data) throws {
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).gloss-\(UUID().uuidString).tmp")
        try data.write(to: tmp)
        if rename(tmp.path, url.path) != 0 {
            let code = errno
            try? FileManager.default.removeItem(at: tmp)
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
    }
}
