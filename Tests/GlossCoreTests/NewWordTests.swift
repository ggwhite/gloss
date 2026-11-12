import XCTest
@testable import GlossCore

final class NewWordTests: XCTestCase {
    let note = """
    # Words

    ## 拼字

    | 正確拼法 | 你打的 | 中文 | 記法 | 次數 |
    |---|---|---|---|---|
    | flombert | flombart | 盒子 | e | 2 |

    ## 問過的字

    | 字 | 中文 | 例句 |
    |---|---|---|
    | zelquin | 微調 | Please zelquin the config. |
    | Flombert | 盒子 | A flombert of cables. |

    ## 其他
    text
    """

    func testAskedDeckParsesWordMeaningExample() {
        let deck = VocabParser.parse(note, deck: .asked)
        XCTAssertEqual(deck.map(\.word), ["zelquin", "Flombert"])
        XCTAssertEqual(deck[0].meaning, "微調")
        XCTAssertEqual(deck[0].hint, "Please zelquin the config.")
        XCTAssertEqual(deck[0].count, 1)
        XCTAssertEqual(deck[0].deck, .asked)
    }

    func testAWordInTwoDecksIsQuizzedOnce() {
        var snap = VaultSnapshot()
        snap.decks = VocabParser.parse(note)
        let words = snap.entries(for: [.spelling, .asked]).map(\.word)
        XCTAssertEqual(words, ["flombert", "zelquin"], "Flombert in 問過的字 is the same word as flombert")
    }

    func testAddRowAtTheEndOfTheTable() throws {
        let out = try AskedTable.add(word: "quorble", meaning: "抱怨", example: "Don't quorble | grumble.", to: note).get()
        let lines = out.components(separatedBy: "\n")
        let i = try XCTUnwrap(lines.firstIndex(of: "| Flombert | 盒子 | A flombert of cables. |"))
        XCTAssertEqual(lines[i + 1], "| quorble | 抱怨 | Don't quorble \\| grumble. |")
        XCTAssertEqual(lines[i + 2], "", "the blank line before the next heading stays")
        XCTAssertEqual(VocabParser.parse(out, deck: .asked).last?.hint, "Don't quorble | grumble.")
    }

    func testRefusesDuplicatesAndOddTables() {
        XCTAssertEqual(AskedTable.add(word: "ZELQUIN", meaning: "x", example: "", to: note), .failure(.alreadyThere))
        XCTAssertEqual(AskedTable.add(word: "a", meaning: "b", example: "", to: "# none\n"), .failure(.noSection))
        let odd = "## 問過的字\n\n| 字 | 意思 |\n|---|---|\n| a | b |\n"
        XCTAssertEqual(AskedTable.add(word: "c", meaning: "d", example: "", to: odd), .failure(.unexpectedColumns(["字", "意思"])))
    }

    func testLocalStoreAddsAndUpdates() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = NewWordStore(url: dir.appendingPathComponent("words.json"))
        try store.add(NewWord(word: "zelquin", meaning: "微調"))
        try store.add(NewWord(word: "Zelquin", meaning: "微調、調整", example: "Zelquin it."))
        let all = store.load()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].meaning, "微調、調整")
        XCTAssertEqual(all[0].entry.deck, .asked)
        try? FileManager.default.removeItem(at: dir)
    }

    func testLookupParsing() throws {
        let r = try WordLookup.parse("```json\n{\"word\": \"zelquin\", \"meaning_zh\": \"微調\", \"example\": \"Zelquin it.\"}\n```")
        XCTAssertEqual(r, WordLookup(word: "zelquin", meaning_zh: "微調", example: "Zelquin it."))
        XCTAssertTrue(WordLookup.prompt(for: "zelqin").contains("zelqin"))
        XCTAssertThrowsError(try WordLookup.parse("no idea"))
    }
}
