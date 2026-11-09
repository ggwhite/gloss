import XCTest
@testable import GlossCore

final class PracticeTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let now = Date(timeIntervalSince1970: 1_900_000_000)

    func testPracticeNeverChangesTheSchedule() {
        var state = GlossState()
        let before = CardState(box: 3, due: now.addingTimeInterval(86_400), lastCorrectDay: nil)
        state.cards["vexil"] = before
        let s = QuizSession(cards: [VocabEntry(word: "vexil"), VocabEntry(word: "plonk")], state: state,
                            scheduler: LeitnerScheduler(calendar: calendar), practice: true, now: { self.now })
        XCTAssertTrue(s.submit("vexil")!.correct)
        XCTAssertFalse(s.submit("plnok")!.correct)
        XCTAssertEqual(s.state.cards["vexil"], before, "box and due time unchanged")
        XCTAssertNil(s.state.cards["plonk"], "a never-studied card stays new")
        let day = s.state.stats(for: Day(now, calendar: calendar))
        XCTAssertEqual(day.practiced, 2)
        XCTAssertEqual(day.practiceCorrect, 1)
        XCTAssertEqual(day.answered, 0, "practice does not count for accuracy")
        XCTAssertEqual(s.queue.map(\.word), ["plonk"], "a wrong practice card still comes back")
    }

    func testOldStateFileStillLoads() throws {
        let json = #"{"version":1,"cards":{},"daily":{"2030-03-10":{"answered":4,"correct":3,"newIntroduced":2}}}"#
        let st = try JSONDecoder().decode(GlossState.self, from: Data(json.utf8))
        XCTAssertEqual(st.daily["2030-03-10"], DailyStats(answered: 4, correct: 3, newIntroduced: 2))
    }

    func testHardestByCountThenLowestBox() {
        let entries = [VocabEntry(word: "aa", count: 1), VocabEntry(word: "bb", count: 4),
                       VocabEntry(word: "cc", count: 2), VocabEntry(word: "dd", count: 2)]
        let states = ["cc": CardState(box: 4, due: now), "dd": CardState(box: 1, due: now)]
        let picked = Practice.pick(.hardest, from: entries, states: states, today: Day(now, calendar: calendar),
                                   calendar: calendar, limit: 3)
        XCTAssertEqual(picked.map(\.word), ["bb", "dd", "cc"])
    }

    func testRandomIsLimitedAndRepeatableWithASeed() {
        let entries = (1...30).map { VocabEntry(word: "w\($0)") }
        let today = Day(now, calendar: calendar)
        let a = Practice.pick(.random, from: entries, states: [:], today: today, calendar: calendar, seed: 42)
        let b = Practice.pick(.random, from: entries, states: [:], today: today, calendar: calendar, seed: 42)
        XCTAssertEqual(a.count, Practice.roundSize)
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set(a.map(\.word)).count, a.count, "no repeats")
    }

    func testTodayInAnswerOrder() {
        let entries = [VocabEntry(word: "x1"), VocabEntry(word: "x2"), VocabEntry(word: "x3")]
        let states = [
            "x1": CardState(box: 1, due: now, lastReviewed: now.addingTimeInterval(-60)),
            "x2": CardState(box: 1, due: now, lastReviewed: now.addingTimeInterval(-3 * 86_400)),
            "x3": CardState(box: 2, due: now, lastReviewed: now.addingTimeInterval(-600)),
        ]
        let today = Day(now, calendar: calendar)
        XCTAssertEqual(Practice.pick(.today, from: entries, states: states, today: today, calendar: calendar).map(\.word),
                       ["x3", "x1"])
        XCTAssertEqual(Practice.available(.today, from: entries, states: states, today: today, calendar: calendar), 2)
    }
}
