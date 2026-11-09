import XCTest
@testable import GlossCore

final class SlotTests: XCTestCase {
    func testEmptyShowsFirstLetterHint() {
        let r = CardPrompt.slots(for: "blorp", typed: "")
        XCTAssertEqual(r.slots, [.hint("b"), .empty, .empty, .empty, .empty])
        XCTAssertEqual(r.overflow, 0)
    }

    func testTypedLettersFillInOrderAndKeepSeparators() {
        let r = CardPrompt.slots(for: "wib dazzle", typed: "WIB d")
        XCTAssertEqual(r.slots, [.typed("w"), .typed("i"), .typed("b"), .separator(" "), .typed("d"),
                                 .empty, .empty, .empty, .empty, .empty])
    }

    func testOverflowCountsExtraLetters() {
        let r = CardPrompt.slots(for: "ab", typed: "abcd")
        XCTAssertEqual(r.slots, [.typed("a"), .typed("b")])
        XCTAssertEqual(r.overflow, 2)
    }

    func testWrongLettersAreNotRevealedWhileTyping() {
        let r = CardPrompt.slots(for: "zintle", typed: "zx")
        XCTAssertEqual(r.slots.first, .typed("z"))
        XCTAssertEqual(r.slots[1], .typed("x"), "shown as typed, not marked wrong")
    }
}
