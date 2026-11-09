import XCTest
@testable import GlossCore

final class OverviewTests: XCTestCase {
    let calendar = Calendar(identifier: .gregorian)
    let today = Day(iso: "2030-05-10")!

    func testHealth() {
        XCTAssertEqual(Overview.health(answered: 4, correct: 4, due: 0), .gettingStarted)
        XCTAssertEqual(Overview.health(answered: 10, correct: 9, due: 3), .good)
        XCTAssertEqual(Overview.health(answered: 10, correct: 9, due: 25), .fair, "a big backlog is not good")
        XCTAssertEqual(Overview.health(answered: 10, correct: 6, due: 0), .fair)
        XCTAssertEqual(Overview.health(answered: 10, correct: 5, due: 0), .needsPractice)
    }

    func testStreak() {
        var st = GlossState()
        for iso in ["2030-05-01", "2030-05-02", "2030-05-03", "2030-05-08", "2030-05-09"] {
            st.daily[iso] = DailyStats(answered: 2, correct: 1)
        }
        st.daily["2030-05-07"] = DailyStats(answered: 0, correct: 0)
        var s = Overview.streak(st, today: today, calendar: calendar)
        XCTAssertEqual(s.current, 2, "ends yesterday")
        XCTAssertEqual(s.best, 3)
        st.daily["2030-05-10"] = DailyStats(answered: 1, correct: 1)
        s = Overview.streak(st, today: today, calendar: calendar)
        XCTAssertEqual(s.current, 3)
        XCTAssertEqual(Overview.streak(GlossState(), today: today, calendar: calendar).current, 0)
    }

    func testBoxCounts() {
        let entries = ["ka", "kb", "kc", "kd"].map { VocabEntry(word: $0) }
        let states = ["ka": CardState(box: 1, due: .distantPast), "kb": CardState(box: 5, due: .distantPast),
                      "kc": CardState(box: 1, due: .distantPast)]
        XCTAssertEqual(Overview.boxCounts(entries, states: states), [1, 2, 0, 0, 0, 1])
    }

    func testRecommendDueCardsFirstWithoutSpoilingTheWord() {
        let due = [VocabEntry(word: "plorvent", meaning: "雜訊", count: 2), VocabEntry(word: "skibble", meaning: "零件", count: 5)]
        let r = Overview.recommend(due: due, week: [CategoryCount(category: "冠詞", count: 3)], fixShortcut: "⌃⌥E")
        XCTAssertEqual(r.action, .quiz)
        XCTAssertEqual(r.title, "Practise 2 cards")
        XCTAssertTrue(r.detail.contains("零件"))
        XCTAssertFalse(r.detail.contains("skibble"), "the answer is not shown")
    }

    func testRecommendWorstCategoryThenFixer() {
        let week = [CategoryCount(category: "冠詞", count: 1), CategoryCount(category: "介系詞", count: 4)]
        let r = Overview.recommend(due: [], week: week, fixShortcut: "⌃⌥E")
        XCTAssertEqual(r.action, .stats)
        XCTAssertEqual(r.title, "Watch your #介系詞")
        let none = Overview.recommend(due: [], week: [CategoryCount(category: "冠詞", count: 0)], fixShortcut: "⌃⌥E")
        XCTAssertEqual(none.action, .fix)
        XCTAssertTrue(none.detail.contains("⌃⌥E"))
    }

    func testRecommendPracticeWhenNothingIsDue() {
        let r = Overview.recommend(due: [], week: [CategoryCount(category: "冠詞", count: 1)], fixShortcut: "⌃⌥E", canPractise: true)
        XCTAssertEqual(r.action, .practice)
        let busyWeek = Overview.recommend(due: [], week: [CategoryCount(category: "冠詞", count: 5)], fixShortcut: "⌃⌥E", canPractise: true)
        XCTAssertEqual(busyWeek.action, .stats, "a bad week still comes first")
    }
}
