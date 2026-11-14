import XCTest
@testable import GlossCore

final class WordNotesTests: XCTestCase {
    let entries = [
        VocabEntry(word: "flombert", meaning: "盒子", hint: "flom + bert", count: 3, deck: .spelling),
        VocabEntry(word: "zelquin", meaning: "微調", hint: "Please zelquin it.", count: 1, deck: .asked),
        VocabEntry(word: "quorble", meaning: "", hint: "差別說明", count: 1, deck: .usage),
    ]

    func testExamplesComeFromTheTableOrTheNotes() {
        let notes = ["quorble": WordNote(meaning: "抱怨", example: "Don't quorble about it.")]
        let info = WordInfo.build(entries, notes: notes)
        XCTAssertEqual(info[0].example, "", "spelling rows have no example until Claude writes one")
        XCTAssertEqual(info[0].hint, "flom + bert")
        XCTAssertEqual(info[1].example, "Please zelquin it.", "問過的字 has its own example")
        XCTAssertEqual(info[1].hint, "", "its hint column is the example")
        XCTAssertEqual(info[2].meaning, "抱怨", "a missing meaning is filled from the notes")
        XCTAssertEqual(info[2].example, "Don't quorble about it.")
    }

    func testBatchesOnlyMissingExamples() {
        let many = (1...45).map { VocabEntry(word: "w\($0)", meaning: "m") } + [entries[1]]
        let b = ExampleBatch.batches(WordInfo.build(many, notes: [:]))
        XCTAssertEqual(b.map(\.count), [20, 20, 5], "zelquin already has one")
    }

    func testPromptListsWordsWithMeanings() {
        let p = ExampleBatch.prompt(for: [("flombert", "盒子"), ("quorble", "")])
        XCTAssertTrue(p.contains("- flombert (盒子)"))
        XCTAssertTrue(p.contains("- quorble\n") || p.hasSuffix("- quorble"))
    }

    func testParseKeepsOnlyAskedWords() throws {
        let out = """
        ```json
        {"items": [{"word": "Flombert", "meaning_zh": "盒子", "example": "Put the cables in the  flombert."},
                   {"word": "other", "meaning_zh": "x", "example": "Not asked."},
                   {"word": "quorble", "meaning_zh": "抱怨", "example": ""}]}
        ```
        """
        let notes = try ExampleBatch.parse(out, asked: ["flombert", "quorble"])
        XCTAssertEqual(Set(notes.keys), ["flombert"], "unasked words and empty examples are dropped")
        XCTAssertEqual(notes["flombert"]?.example, "Put the cables in the flombert.")
        XCTAssertThrowsError(try ExampleBatch.parse("sorry", asked: ["a"]))
    }

    func testStoreMerges() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = WordNoteStore(url: dir.appendingPathComponent("word-notes.json"))
        try store.merge(["Flombert": WordNote(meaning: "盒子", example: "A.")])
        try store.merge(["quorble": WordNote(meaning: "抱怨", example: "B.")])
        XCTAssertEqual(Set(store.load().keys), ["flombert", "quorble"])
        try? FileManager.default.removeItem(at: dir)
    }
}
