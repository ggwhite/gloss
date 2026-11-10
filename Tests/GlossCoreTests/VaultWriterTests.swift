import XCTest
@testable import GlossCore

final class VaultWriterTests: XCTestCase {
    var root: URL!
    let day = Day(iso: "2026-11-10")!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-writer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - helpers

    var logURL: URL { root.appendingPathComponent("錯誤紀錄/2026-11-10.md") }
    var vocabURL: URL { root.appendingPathComponent("單字.md") }

    func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func read(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
    }

    func item(_ from: String, _ to: String, _ why: String, _ cat: String,
              meaning: String = "", hint: String = "", properNoun: Bool = false) -> FixResult.Item {
        FixResult.Item(from: from, to: to, why_zh: why, category: cat, meaning: meaning, hint: hint, proper_noun: properNoun)
    }

    func result(_ items: [FixResult.Item]) -> FixResult {
        FixResult(fixed: "x", short: "x", mistakes: items)
    }

    let vocab = """
    ---
    title: t
    ---
    # Words

    ## 拼字（made-up）

    | 正確拼法 | 你打的 | 中文 | 記法 | 次數 |
    |---|---|---|---|---|
    | **blorpify** | blorpefy | 弄亂 | **blorp** + ify | 3 |
    | `zintle` | zintel? | 閃光 | 結尾 `-tle` | 2 |

    ## 用字（made-up）

    | 該用 | 你用的 | 中文 | 差別 | 次數 |
    |---|---|---|---|---|
    | snoodle | snarfle | 打盹 | snoodle 是動詞 | 1 |

    ## 問過的字

    | 字 | 意思 |
    |---|---|
    | glemp | 不算 |

    """

    // MARK: - 錯誤紀錄

    func testLogLineFormat() {
        XCTAssertEqual(FixLog.line(for: item("he go", "he goes", "第三人稱單數", "動詞形式")),
                       "- `he go` → `he goes` — 第三人稱單數 #動詞形式")
        XCTAssertEqual(FixLog.line(for: item("recieve", "receive", "i 在 e 前", "#拼字")),
                       "- `recieve` → `receive` — i 在 e 前 #拼字", "a leading # in the category is accepted")
    }

    func testCreatesNewLogFile() {
        let report = VaultWriter.save(result([item("he go", "he goes", "第三人稱單數", "動詞形式")]), root: root, day: day)
        XCTAssertEqual(read(logURL), "- `he go` → `he goes` — 第三人稱單數 #動詞形式\n")
        XCTAssertEqual(report.saved, 1)
        XCTAssertEqual(report.summary, "Saved 1 mistake to 錯誤紀錄")
    }

    func testAppendsWithoutChangingEarlierBytes() throws {
        let earlier = "# 2026-11-10\n\n- `a apple` → `an apple` — 母音前用 an #冠詞\n"
        try write(earlier, to: logURL)
        let report = VaultWriter.save(result([
            item("on Monday", "on Monday", "x", "介系詞"), // no change: skipped
            item("in the weekend", "on the weekend", "週末用 on", "介系詞"),
            item("two cat", "two cats", "複數加 s", "單複數"),
        ]), root: root, day: day)
        XCTAssertEqual(read(logURL), earlier
            + "- `in the weekend` → `on the weekend` — 週末用 on #介系詞\n"
            + "- `two cat` → `two cats` — 複數加 s #單複數\n")
        XCTAssertEqual(report.summary, "Saved 2 mistakes to 錯誤紀錄")
    }

    func testFileWithoutTrailingNewline() throws {
        try write("- `a` → `b` — c #冠詞", to: logURL)
        VaultWriter.save(result([item("he go", "he goes", "第三人稱單數", "動詞形式")]), root: root, day: day)
        XCTAssertEqual(read(logURL), "- `a` → `b` — c #冠詞\n- `he go` → `he goes` — 第三人稱單數 #動詞形式\n")
    }

    func testSameResultIsSavedOnce() throws {
        try write(vocab, to: vocabURL)
        let r = result([item("he go", "he goes", "第三人稱單數", "動詞形式"),
                        item("blorpefy", "blorpify", "中間是 i", "拼字")])
        let first = VaultWriter.save(r, root: root, day: day)
        let log = read(logURL)
        let words = read(vocabURL)
        let second = VaultWriter.save(r, root: root, day: day)
        XCTAssertEqual(first.saved, 2)
        XCTAssertEqual(second.saved, 0)
        XCTAssertEqual(second.duplicates, 2)
        XCTAssertEqual(read(logURL), log, "no duplicate lines")
        XCTAssertEqual(read(vocabURL), words, "the count goes up once")
        XCTAssertEqual(second.summary, "Already saved to 錯誤紀錄")
    }

    func testDuplicateInsideOneResult() {
        let m = item("he go", "he goes", "第三人稱單數", "動詞形式")
        VaultWriter.save(result([m, m]), root: root, day: day)
        XCTAssertEqual(read(logURL), "- `he go` → `he goes` — 第三人稱單數 #動詞形式\n")
    }

    func testSkippedCategories() {
        let report = VaultWriter.save(result([
            item("i think", "I think", "大寫", "拼字"),       // capitalization only
            item("Hello how are you", "Hello, how are you?", "標點", "句型"), // punctuation only
            item("its fine", "it's fine", "縮寫", "標點"),      // not a known category
            item("foo", "bar", "x", ""),                        // no category
        ]), root: root, day: day)
        XCTAssertNil(read(logURL), "nothing to write, no file created")
        XCTAssertEqual(report.saved, 0)
        XCTAssertEqual(report.skipped, 4)
    }

    func testMissingVaultFolderWritesNothing() {
        let gone = root.appendingPathComponent("not-here")
        let report = VaultWriter.save(result([item("he go", "he goes", "第三人稱單數", "動詞形式")]), root: gone, day: day)
        XCTAssertFalse(FileManager.default.fileExists(atPath: gone.path))
        XCTAssertEqual(report.saved, 0)
        XCTAssertEqual(report.warnings.count, 1)
    }

    let apostropheVocab = """
    ## 拼字

    | 正確拼法 | 你打的 | 中文 | 記法 | 次數 |
    |---|---|---|---|---|
    | its | it's | 它的 | 所有格沒有 ' | 2 |
    | it's | its | 它是 | it is 的縮寫 | 1 |

    """

    func testApostropheIsNotPunctuation() {
        XCTAssertFalse(FixLog.isCaseOrPunctuationOnly("it's", "its"))
        XCTAssertFalse(FixLog.isCaseOrPunctuationOnly("its", "it’s"), "curly apostrophe")
        XCTAssertTrue(FixLog.isCaseOrPunctuationOnly("Hello how are you", "hello, how are you!"))
    }

    func testRemovedApostropheIsSavedAndCounted() throws {
        try write(apostropheVocab, to: vocabURL)
        let report = VaultWriter.save(result([item("it's", "its", "所有格不加 '", "拼字")]), root: root, day: day)
        XCTAssertEqual(report.saved, 1)
        XCTAssertEqual(read(logURL), "- `it's` → `its` — 所有格不加 ' #拼字\n")
        XCTAssertEqual(read(vocabURL), apostropheVocab.replacingOccurrences(
            of: "| its | it's | 它的 | 所有格沒有 ' | 2 |", with: "| its | it's | 它的 | 所有格沒有 ' | 3 |"))
    }

    func testAddedApostropheIsSavedAndCounted() throws {
        try write(apostropheVocab, to: vocabURL)
        let report = VaultWriter.save(result([item("its", "it's", "it is 要加 '", "拼字")]), root: root, day: day)
        XCTAssertEqual(report.saved, 1)
        XCTAssertEqual(read(logURL), "- `its` → `it's` — it is 要加 ' #拼字\n")
        XCTAssertEqual(read(vocabURL), apostropheVocab.replacingOccurrences(
            of: "| it's | its | 它是 | it is 的縮寫 | 1 |", with: "| it's | its | 它是 | it is 的縮寫 | 2 |"))
    }

    // MARK: - 單字.md

    func testIncrementsExistingRowAndKeepsOtherBytes() throws {
        try write(vocab, to: vocabURL)
        let report = VaultWriter.save(result([item("blorpefy", "Blorpify", "中間是 i", "拼字")]), root: root, day: day)
        let expected = vocab.replacingOccurrences(
            of: "| **blorpify** | blorpefy | 弄亂 | **blorp** + ify | 3 |",
            with: "| **blorpify** | blorpefy | 弄亂 | **blorp** + ify | 4 |")
        XCTAssertEqual(read(vocabURL), expected)
        XCTAssertEqual(report.warnings, [])
        XCTAssertEqual(report.vocabChanged, 1)
    }

    func testAddsNewWrongSpellingToTyped() throws {
        try write(vocab, to: vocabURL)
        VaultWriter.save(result([item("zintel", "zintle", "結尾 -tle", "拼字")]), root: root, day: day)
        let expected = vocab.replacingOccurrences(
            of: "| `zintle` | zintel? | 閃光 | 結尾 `-tle` | 2 |",
            with: "| `zintle` | zintel?, zintel | 閃光 | 結尾 `-tle` | 3 |")
        XCTAssertEqual(read(vocabURL), expected)
    }

    func testInsertsNewRowAtEndOfTheRightTable() throws {
        try write(vocab, to: vocabURL)
        VaultWriter.save(result([
            item("quorvent", "quorvant", "是 a", "拼字", meaning: "安靜", hint: "quor + **vant**"),
            item("glintly", "glintwise", "副詞", "用字", meaning: "順便", hint: "glintwise 是副詞"),
        ]), root: root, day: day)
        let expected = vocab
            .replacingOccurrences(
                of: "| `zintle` | zintel? | 閃光 | 結尾 `-tle` | 2 |\n",
                with: "| `zintle` | zintel? | 閃光 | 結尾 `-tle` | 2 |\n| quorvant | quorvent | 安靜 | quor + **vant** | 1 |\n")
            .replacingOccurrences(
                of: "| snoodle | snarfle | 打盹 | snoodle 是動詞 | 1 |\n",
                with: "| snoodle | snarfle | 打盹 | snoodle 是動詞 | 1 |\n| glintwise | glintly | 順便 | glintwise 是副詞 | 1 |\n")
        XCTAssertEqual(read(vocabURL), expected)
        XCTAssertEqual(VocabParser.parse(expected, deck: .spelling).last?.word, "quorvant")
    }

    func testProperNounIsLoggedButNotAddedToVocab() throws {
        try write(vocab, to: vocabURL)
        let report = VaultWriter.save(result([item("Githbu", "GitHub", "拼錯", "拼字", properNoun: true)]), root: root, day: day)
        XCTAssertEqual(report.saved, 1)
        XCTAssertEqual(read(vocabURL), vocab)
    }

    func testMissingTableMeansNoVocabWrite() throws {
        let noTable = "# Words\n\n## 拼字（made-up）\n\nno table yet\n\n## 用字\n"
        try write(noTable, to: vocabURL)
        let report = VaultWriter.save(result([item("quorvent", "quorvant", "是 a", "拼字", meaning: "安靜")]), root: root, day: day)
        XCTAssertEqual(read(vocabURL), noTable)
        XCTAssertEqual(report.saved, 1, "the 錯誤紀錄 line is still written")
        XCTAssertEqual(report.warnings.count, 1)
        XCTAssertTrue(report.summary.contains("單字.md not changed"), report.summary)
    }

    func testMissingHeadingMeansNoVocabWrite() throws {
        let noHeading = "# Words\n\n## 用字\n\n| 該用 | 你用的 | 中文 | 差別 | 次數 |\n|---|---|---|---|---|\n"
        try write(noHeading, to: vocabURL)
        let report = VaultWriter.save(result([item("quorvent", "quorvant", "是 a", "拼字")]), root: root, day: day)
        XCTAssertEqual(read(vocabURL), noHeading)
        XCTAssertEqual(report.warnings.count, 1)
    }

    func testAmbiguousRowMeansNoVocabWrite() throws {
        let twice = vocab.replacingOccurrences(
            of: "| `zintle` | zintel? | 閃光 | 結尾 `-tle` | 2 |\n",
            with: "| `zintle` | zintel? | 閃光 | 結尾 `-tle` | 2 |\n| Blorpify | blorpify | 重複 | | 5 |\n")
        try write(twice, to: vocabURL)
        let report = VaultWriter.save(result([item("blorpefy", "blorpify", "中間是 i", "拼字")]), root: root, day: day)
        XCTAssertEqual(read(vocabURL), twice)
        XCTAssertEqual(report.warnings.count, 1)
    }

    func testOneBadChangeBlocksTheWholeVocabWrite() {
        let r = VocabEditor.apply([
            .init(word: "blorpify", typed: "blorpefy", meaning: "", hint: "", deck: .spelling),
            .init(word: "x", typed: "y", meaning: "", hint: "", deck: .usage),
        ], to: "## 拼字\n\n| 正確拼法 | 你打的 | 中文 | 記法 | 次數 |\n|---|---|---|---|---|\n| blorpify | blorpefy | a | b | 1 |\n")
        guard case .failure = r else { return XCTFail("expected a failure, got \(r)") }
    }

    func testFixResultDecodesMeaningAndHint() throws {
        let r = try FixPrompt.parse(#"{"fixed":"a","short":"a","mistakes":[{"from":"recieve","to":"receive","why_zh":"x","category":"拼字","meaning":"收到","hint":"e 在 i 前","proper_noun":false}]}"#)
        XCTAssertEqual(r.mistakes.first?.meaning, "收到")
        XCTAssertEqual(r.mistakes.first?.hint, "e 在 i 前")
        XCTAssertEqual(r.mistakes.first?.proper_noun, false)
        let old = try FixPrompt.parse(#"{"fixed":"a","mistakes":[{"from":"a","to":"b","why_zh":"x","category":"冠詞"}]}"#)
        XCTAssertEqual(old.mistakes.first?.meaning, "")
        XCTAssertEqual(old.mistakes.first?.proper_noun, false)
    }

    func testPromptListsOnlyKnownCategories() {
        let p = FixPrompt.build(for: "hi")
        for c in MistakeCategory.known { XCTAssertTrue(p.contains(c), c) }
        XCTAssertTrue(p.contains("meaning"))
        XCTAssertTrue(p.contains("hint"))
    }
}
