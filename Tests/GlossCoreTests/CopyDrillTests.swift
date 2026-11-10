import XCTest
@testable import GlossCore

final class CopyDrillTests: XCTestCase {
    func testThreeRightCopiesFinish() {
        var d = CopyDrill(word: "Glimbora", required: 3)
        XCTAssertEqual(d.submit("glimbora"), .counted)
        XCTAssertEqual(d.submit("  GLIMBORA "), .counted, "case and spaces ignored")
        XCTAssertFalse(d.isFinished)
        XCTAssertEqual(d.submit("glimbora"), .finished)
        XCTAssertTrue(d.isFinished)
        XCTAssertEqual(d.done, 3)
    }

    func testWrongCopyDoesNotCount() {
        var d = CopyDrill(word: "glimbora", required: 2)
        XCTAssertEqual(d.submit("glimbra"), .wrong)
        XCTAssertEqual(d.done, 0)
        XCTAssertEqual(d.misses, 1)
        XCTAssertEqual(d.submit("glimbora"), .counted)
    }

    func testEmptyIsASkipNotAMiss() {
        var d = CopyDrill(word: "glimbora", required: 2)
        XCTAssertEqual(d.submit("   "), .empty)
        XCTAssertEqual(d.misses, 0)
    }

    func testAtLeastOneCopy() {
        XCTAssertEqual(CopyDrill(word: "x", required: 0).required, 1)
    }

    func testLetterMatches() {
        XCTAssertEqual(CardPrompt.letterMatches(for: "wib dax", typed: "wob d"),
                       [true, false, true, nil, true, nil, nil])
        XCTAssertEqual(CardPrompt.letterMatches(for: "ab", typed: ""), [nil, nil])
    }
}
