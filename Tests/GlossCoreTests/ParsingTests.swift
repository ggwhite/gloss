import XCTest
@testable import GlossCore

final class TableParsingTests: XCTestCase {
    let fixture = """
    ---
    title: test
    ---
    # Words

    ## 拼字（made-up）

    | 正確拼法 | 你打的 | 中文 | 記法 | 次數 |
    |---|---|---|---|---|
    | **blorpify** | blorpefy | 弄亂 | **blorp** + ify | 3 |
    | `zintle` | zintel? | 閃光 | 結尾 `-tle` | 2 |
    | frannock? | fr???ck | 小屋 | f-r-a-n-n | x |
    | wib dazzle | wibdazzle | 炫耀 | 兩個字 |
    | quorvant | quorvent | 安靜 |
    |  | empty | 空 | | 1 |
    | Blorpify | blorpify | 重複 | | 5 |

    ## 用字（made-up）

    | 該用 | 你用的 | 中文 | 差別 | 次數 |
    |---|---|---|---|---|
    | snoodle | snarfle | 打盹 | snoodle 是動詞 | 1 |

    ## 問過的字

    | 字 | 意思 |
    |---|---|
    | glemp | 不算 |
    """

    func testSpellingDeckParsesRows() {
        let deck = VocabParser.parse(fixture, deck: .spelling)
        XCTAssertEqual(deck.map(\.word), ["blorpify", "zintle", "frannock", "wib dazzle", "quorvant"])
    }

    func testBoldAndBackticksAreStripped() {
        let deck = VocabParser.parse(fixture, deck: .spelling)
        XCTAssertEqual(deck[0].word, "blorpify")
        XCTAssertEqual(deck[0].hint, "blorp + ify")
        XCTAssertEqual(deck[1].word, "zintle")
        XCTAssertEqual(deck[1].hint, "結尾 -tle")
    }

    func testQuestionMarks() {
        let deck = VocabParser.parse(fixture, deck: .spelling)
        XCTAssertEqual(deck[2].word, "frannock", "the answer drops ?")
        XCTAssertEqual(deck[2].typed, "fr???ck", "the typed column keeps ?")
        XCTAssertEqual(deck[1].typed, "zintel?")
    }

    func testCountDefaultsToOne() {
        let deck = VocabParser.parse(fixture, deck: .spelling)
        XCTAssertEqual(deck[1].count, 2)
        XCTAssertEqual(deck[2].count, 1, "unparsable count")
        XCTAssertEqual(deck[3].count, 1, "missing count column")
    }

    func testMissingColumns() {
        let deck = VocabParser.parse(fixture, deck: .spelling)
        XCTAssertEqual(deck[4].word, "quorvant")
        XCTAssertEqual(deck[4].meaning, "安靜")
        XCTAssertEqual(deck[4].hint, "")
        XCTAssertEqual(deck[4].count, 1)
    }

    func testDuplicateKeepsHighestCount() {
        let deck = VocabParser.parse(fixture, deck: .spelling)
        XCTAssertEqual(deck.filter { $0.word.lowercased() == "blorpify" }.count, 1)
        XCTAssertEqual(deck[0].count, 5)
    }

    func testUsageDeckIsSeparate() {
        let decks = VocabParser.parse(fixture)
        XCTAssertEqual(decks[.usage]?.map(\.word), ["snoodle"])
        XCTAssertEqual(decks[.usage]?.first?.deck, .usage)
        XCTAssertFalse(decks[.spelling]!.contains { $0.word == "glemp" }, "other sections are ignored")
    }

    func testMissingSection() {
        XCTAssertEqual(VocabParser.parse("# nothing here\n", deck: .spelling), [])
    }

    func testEscapedPipeStaysInCell() {
        let text = "## 拼字\n\n| a | b | c | d | e |\n|---|---|---|---|---|\n| trivok | x | 一 \\| 二 | `a|b` | 2 |\n"
        let e = VocabParser.parse(text, deck: .spelling)
        XCTAssertEqual(e.first?.meaning, "一 | 二")
        XCTAssertEqual(e.first?.hint, "a|b")
        XCTAssertEqual(e.first?.count, 2)
    }

    func testMarkdownStrip() {
        XCTAssertEqual(Markdown.strip("**bold** and `code` and [link](http://x)"), "bold and code and link")
        XCTAssertEqual(Markdown.strip("  many   spaces "), "many spaces")
    }
}

final class MistakeParsingTests: XCTestCase {
    let day = Day(iso: "2030-01-15")!

    func testBasicLine() {
        let m = MistakeParser.parseLine("- `a blorp` → `the blorp` — 特定的那個要加 the #冠詞", day: day)
        XCTAssertEqual(m, Mistake(day: day, original: "a blorp", fix: "the blorp", explanation: "特定的那個要加 the", categories: ["冠詞"]))
    }

    func testFixWithExtraText() {
        let m = MistakeParser.parseLine("- `zintel` → `zintle`（或用 `zint`）— 結尾是 le #拼字", day: day)
        XCTAssertEqual(m?.original, "zintel")
        XCTAssertEqual(m?.fix, "zintle")
        XCTAssertEqual(m?.categories, ["拼字"])
    }

    func testSeveralTags() {
        let m = MistakeParser.parseLine("- `he blorp` → `he blorps` — 第三人稱 #動詞形式 #單複數", day: day)
        XCTAssertEqual(m?.categories, ["動詞形式", "單複數"])
        XCTAssertEqual(m?.explanation, "第三人稱")
    }

    func testNonMistakeLinesAreSkipped() {
        let text = """
        # 2030-01-15
        some note
        - a list item without an arrow
        - `wib` → `wob` — 說明 #用字
        """
        let all = MistakeParser.parse(text, day: day)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].fix, "wob")
    }

    func testDayFromFileName() {
        XCTAssertEqual(MistakeParser.day(fromFileName: "2030-01-15.md"), day)
        XCTAssertNil(MistakeParser.day(fromFileName: "notes.md"))
        XCTAssertNil(MistakeParser.day(fromFileName: "2030-1-5.md"))
    }
}

final class FixParsingTests: XCTestCase {
    func testParsesFencedJSON() throws {
        let out = """
        ```json
        {"fixed": "He goes home.", "short": "He's heading home.", "mistakes": [{"from": "go", "to": "goes", "why_zh": "第三人稱單數", "category": "動詞形式"}]}
        ```
        """
        let r = try FixPrompt.parse(out)
        XCTAssertEqual(r.fixed, "He goes home.")
        XCTAssertEqual(r.mistakes.first?.category, "動詞形式")
    }

    func testMissingShortFallsBackToFixed() throws {
        let r = try FixPrompt.parse(#"{"fixed": "OK."}"#)
        XCTAssertEqual(r.short, "OK.")
        XCTAssertEqual(r.mistakes, [])
    }

    func testNoJSON() {
        XCTAssertThrowsError(try FixPrompt.parse("sorry, I can't")) { e in
            XCTAssertEqual(e as? FixParseError, .noJSON)
        }
    }

    func testPromptContainsText() {
        XCTAssertTrue(FixPrompt.build(for: "he go home").contains("he go home"))
    }
}
