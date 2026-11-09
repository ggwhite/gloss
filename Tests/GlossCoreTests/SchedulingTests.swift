import XCTest
@testable import GlossCore

/// A clock the test moves by hand.
final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class LeitnerTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }()
    lazy var scheduler = LeitnerScheduler(calendar: calendar)
    /// 2030-03-10 10:00 in Taipei.
    lazy var morning = calendar.date(from: DateComponents(year: 2030, month: 3, day: 10, hour: 10))!

    func testIntervals() {
        XCTAssertEqual(LeitnerScheduler.intervals, [600, 86_400, 259_200, 604_800, 1_814_400])
    }

    func testNewCardIsDue() {
        XCTAssertTrue(scheduler.isDue(nil, now: morning))
    }

    func testCorrectMovesUpOneBox() {
        var s = scheduler.apply(correct: true, to: nil, now: morning)
        XCTAssertEqual(s.box, 1)
        s = scheduler.apply(correct: true, to: s, now: morning.addingTimeInterval(86_400))
        XCTAssertEqual(s.box, 2)
        XCTAssertEqual(s.due, morning.addingTimeInterval(86_400 * 2))
    }

    func testBoxCapsAtFive() {
        var s = CardState(box: 5, due: morning)
        s = scheduler.apply(correct: true, to: s, now: morning)
        XCTAssertEqual(s.box, 5)
        XCTAssertEqual(s.due, morning.addingTimeInterval(21 * 86_400))
    }

    func testWrongGoesToBoxOneInTenMinutes() {
        let clock = TestClock(morning)
        let s = scheduler.apply(correct: false, to: CardState(box: 4, due: morning), now: clock.now)
        XCTAssertEqual(s.box, 1)
        XCTAssertEqual(s.due, morning.addingTimeInterval(600))
        clock.advance(599)
        XCTAssertFalse(scheduler.isDue(s, now: clock.now))
        clock.advance(1)
        XCTAssertTrue(scheduler.isDue(s, now: clock.now))
    }

    func testNeverTwiceOnTheSameDayAfterCorrect() {
        let s = scheduler.apply(correct: true, to: nil, now: morning)
        XCTAssertFalse(scheduler.isDue(s, now: morning.addingTimeInterval(3_600)))
        let lateEvening = calendar.date(from: DateComponents(year: 2030, month: 3, day: 10, hour: 23, minute: 59))!
        XCTAssertFalse(scheduler.isDue(s, now: lateEvening))
        let nextDay = calendar.date(from: DateComponents(year: 2030, month: 3, day: 11, hour: 0, minute: 1))!
        XCTAssertTrue(scheduler.isDue(s, now: nextDay))
    }

    func testLapsedCardDoesNotMoveUp() {
        let wrong = scheduler.apply(correct: false, to: CardState(box: 3, due: morning), now: morning)
        let right = scheduler.apply(correct: true, to: wrong, now: morning, lapsedThisSession: true)
        XCTAssertEqual(right.box, 1)
        XCTAssertEqual(right.lastCorrectDay, Day(morning, calendar: calendar))
    }

    func testDueOrderingNewByCount() {
        let entries = [
            VocabEntry(word: "aaa", count: 1),
            VocabEntry(word: "bbb", count: 5),
            VocabEntry(word: "ccc", count: 3),
            VocabEntry(word: "ddd", count: 5),
            VocabEntry(word: "eee", count: 2),
        ]
        var states: [String: CardState] = [:]
        states["eee"] = CardState(box: 1, due: morning.addingTimeInterval(-60))
        states["aaa"] = CardState(box: 2, due: morning.addingTimeInterval(3_600))
        let due = scheduler.dueCards(entries, states: states, now: morning, newLimit: 2)
        XCTAssertEqual(due.map(\.word), ["eee", "bbb", "ddd"])
    }

    func testQuietHoursWrapMidnight() {
        let q = QuietHours.default
        func at(_ h: Int, _ m: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2030, month: 3, day: 10, hour: h, minute: m))!
        }
        XCTAssertTrue(q.contains(at(22), calendar: calendar))
        XCTAssertTrue(q.contains(at(3), calendar: calendar))
        XCTAssertTrue(q.contains(at(8, 59), calendar: calendar))
        XCTAssertFalse(q.contains(at(9), calendar: calendar))
        XCTAssertFalse(q.contains(at(21, 59), calendar: calendar))
        XCTAssertTrue(QuietHours(startHour: 12, endHour: 13).contains(at(12, 30), calendar: calendar))
        XCTAssertFalse(QuietHours(start: 0, end: 0).contains(at(12), calendar: calendar))
    }

    func testNudgePolicy() {
        let q = QuietHours.default
        XCTAssertTrue(NudgePolicy.shouldNudge(now: morning, lastNudge: nil, intervalMinutes: 60, dueCount: 2, quiet: q, calendar: calendar))
        XCTAssertFalse(NudgePolicy.shouldNudge(now: morning, lastNudge: nil, intervalMinutes: 60, dueCount: 0, quiet: q, calendar: calendar))
        XCTAssertFalse(NudgePolicy.shouldNudge(now: morning, lastNudge: morning.addingTimeInterval(-59 * 60), intervalMinutes: 60, dueCount: 2, quiet: q, calendar: calendar))
        XCTAssertTrue(NudgePolicy.shouldNudge(now: morning, lastNudge: morning.addingTimeInterval(-60 * 60), intervalMinutes: 60, dueCount: 2, quiet: q, calendar: calendar))
        let night = morning.addingTimeInterval(13 * 3_600)
        XCTAssertFalse(NudgePolicy.shouldNudge(now: night, lastNudge: nil, intervalMinutes: 60, dueCount: 2, quiet: q, calendar: calendar))
    }
}

final class SessionTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func testWrongAnswerIsRequeuedLater() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_900_000_000))
        let cards = ["one", "two", "three", "four", "five"].map { VocabEntry(word: "w\($0)") }
        let s = QuizSession(cards: cards, state: GlossState(), scheduler: LeitnerScheduler(calendar: calendar), now: { clock.now })
        let out = s.submit("wrong")!
        XCTAssertFalse(out.correct)
        XCTAssertEqual(s.queue.map(\.word), ["wtwo", "wthree", "wfour", "wone", "wfive"])
        XCTAssertEqual(s.state.cards["wone"]?.box, 1)
    }

    func testCorrectAnswerLeavesQueueAndRecordsDay() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_900_000_000))
        let s = QuizSession(cards: [VocabEntry(word: "Glorp")], state: GlossState(), scheduler: LeitnerScheduler(calendar: calendar), now: { clock.now })
        XCTAssertTrue(s.submit("  gLoRp ")!.correct)
        XCTAssertTrue(s.isFinished)
        let today = Day(clock.now, calendar: calendar)
        XCTAssertEqual(s.state.stats(for: today), DailyStats(answered: 1, correct: 1, newIntroduced: 1))
    }

    func testRequeuedCardAtEndWhenQueueShort() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_900_000_000))
        let s = QuizSession(cards: [VocabEntry(word: "ab"), VocabEntry(word: "cd")], state: GlossState(), scheduler: LeitnerScheduler(calendar: calendar), now: { clock.now })
        s.submit("xx")
        XCTAssertEqual(s.queue.map(\.word), ["cd", "ab"])
        s.submit("cd")
        XCTAssertTrue(s.submit("ab")!.correct)
        XCTAssertEqual(s.state.cards["ab"]?.box, 1, "lapsed card stays in box 1")
        XCTAssertEqual(s.state.stats(for: Day(clock.now, calendar: calendar)).answered, 3)
    }

    func testStateStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = StateStore(url: dir.appendingPathComponent("Gloss/state.json"))
        var st = GlossState()
        st.cards["zib"] = CardState(box: 2, due: Date(timeIntervalSince1970: 1_900_000_000), lastCorrectDay: Day(iso: "2030-03-10"))
        st.daily["2030-03-10"] = DailyStats(answered: 3, correct: 2)
        try store.save(st)
        XCTAssertEqual(store.load(), st)
        try? FileManager.default.removeItem(at: dir)
    }

    func testMissingStateFileIsEmpty() {
        XCTAssertEqual(StateStore(url: URL(fileURLWithPath: "/nonexistent/state.json")).load(), GlossState())
    }
}

final class AnswerTests: XCTestCase {
    func testCaseAndSpaces() {
        XCTAssertTrue(AnswerChecker.isCorrect(expected: "Flimbor", typed: "  flimBOR\n"))
        XCTAssertTrue(AnswerChecker.isCorrect(expected: "wib dazzle", typed: "wib   dazzle"))
        XCTAssertFalse(AnswerChecker.isCorrect(expected: "flimbor", typed: ""))
        XCTAssertFalse(AnswerChecker.isCorrect(expected: "flimbor", typed: "flimber"))
    }

    func testDiffSubstitution() {
        XCTAssertEqual(AnswerChecker.diff(expected: "abc", typed: "axc"),
                       [.same("a"), .substituted(expected: "b", typed: "x"), .same("c")])
    }

    func testDiffMissingAndExtra() {
        XCTAssertEqual(AnswerChecker.diff(expected: "abcd", typed: "abd"),
                       [.same("a"), .same("b"), .missing("c"), .same("d")])
        XCTAssertEqual(AnswerChecker.diff(expected: "abd", typed: "abxd"),
                       [.same("a"), .same("b"), .extra("x"), .same("d")])
    }

    func testWrongMask() {
        XCTAssertEqual(AnswerChecker.wrongMask(expected: "zorbitude", typed: "zorbitute"),
                       [false, false, false, false, false, false, false, true, false])
        XCTAssertEqual(AnswerChecker.wrongMask(expected: "abd", typed: "abxd"), [false, false, true])
        XCTAssertEqual(AnswerChecker.wrongMask(expected: "ab", typed: "abz"), [false, true])
        XCTAssertEqual(AnswerChecker.wrongMask(expected: "ab", typed: ""), [true, true])
    }

    func testPromptMask() {
        XCTAssertEqual(CardPrompt.mask("flumbrance"), "f_________")
        XCTAssertEqual(CardPrompt.letterCount("flumbrance"), 10)
        XCTAssertEqual(CardPrompt.mask("wib dazzle"), "w__ ______")
        XCTAssertEqual(CardPrompt.letterCount("wib dazzle"), 9)
        XCTAssertEqual(CardPrompt.text(for: VocabEntry(word: "zintlebo", meaning: "容量")), "容量 → z_______ (8)")
    }
}

final class StatsTests: XCTestCase {
    let calendar = Calendar(identifier: .gregorian)

    func testCategoryWindows() {
        let today = Day(iso: "2030-03-31")!
        let ms = [
            Mistake(day: Day(iso: "2030-03-31"), original: "a", fix: "b", explanation: "", categories: ["拼字"]),
            Mistake(day: Day(iso: "2030-03-25"), original: "a", fix: "b", explanation: "", categories: ["拼字", "冠詞"]),
            Mistake(day: Day(iso: "2030-03-24"), original: "a", fix: "b", explanation: "", categories: ["冠詞"]),
            Mistake(day: Day(iso: "2030-03-02"), original: "a", fix: "b", explanation: "", categories: ["新類"]),
            Mistake(day: Day(iso: "2030-03-01"), original: "a", fix: "b", explanation: "", categories: ["句型"]),
        ]
        let week = GlossStats.categoryCounts(ms, lastDays: 7, today: today, calendar: calendar)
        XCTAssertEqual(week.first { $0.category == "拼字" }?.count, 2)
        XCTAssertEqual(week.first { $0.category == "冠詞" }?.count, 1)
        let month = GlossStats.categoryCounts(ms, lastDays: 30, today: today, calendar: calendar)
        XCTAssertEqual(month.first { $0.category == "冠詞" }?.count, 2)
        XCTAssertEqual(month.first { $0.category == "新類" }?.count, 1)
        XCTAssertEqual(month.first { $0.category == "句型" }?.count, 0, "31 days ago is outside 30 days")
    }

    func testTopRepeated() {
        let e = (1...12).map { VocabEntry(word: "w\(String(format: "%02d", $0))", count: $0 % 4) }
        let top = GlossStats.topRepeated(e)
        XCTAssertEqual(top.count, 10)
        XCTAssertEqual(top.first?.count, 3)
    }

    func testAccuracyPerDay() {
        var st = GlossState()
        st.daily["2030-03-30"] = DailyStats(answered: 4, correct: 3)
        let rows = GlossStats.accuracy(st, lastDays: 3, today: Day(iso: "2030-03-31")!, calendar: calendar)
        XCTAssertEqual(rows.map(\.day.iso), ["2030-03-29", "2030-03-30", "2030-03-31"])
        XCTAssertEqual(rows[1].accuracy, 0.75)
    }

    func testDemoDeckLoads() {
        XCTAssertEqual(DemoDeck.snapshot.decks[.spelling]?.count, 5)
        XCTAssertEqual(DemoDeck.snapshot.mistakes.count, 3)
    }
}

final class VaultTests: XCTestCase {
    func testLoadFromFolderWithSymlink() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let real = base.appendingPathComponent("real")
        try fm.createDirectory(at: real.appendingPathComponent("錯誤紀錄"), withIntermediateDirectories: true)
        try DemoDeck.markdown.write(to: real.appendingPathComponent("單字.md"), atomically: true, encoding: .utf8)
        try DemoDeck.mistakes.write(to: real.appendingPathComponent("錯誤紀錄/2030-03-31.md"), atomically: true, encoding: .utf8)
        let link = base.appendingPathComponent("link")
        try fm.createSymbolicLink(at: link, withDestinationURL: real)

        let snap = Vault.load(path: link.path)
        XCTAssertEqual(snap.problems, [])
        XCTAssertEqual(snap.decks[.spelling]?.first?.word, "flumbrance")
        XCTAssertEqual(snap.mistakes.count, 3)
        XCTAssertEqual(snap.mistakes.first?.day, Day(iso: "2030-03-31"))

        let before = Vault.fingerprint(path: link.path)
        try "- `x` → `y` — z #拼字\n".write(to: real.appendingPathComponent("錯誤紀錄/2030-04-01.md"), atomically: true, encoding: .utf8)
        XCTAssertNotEqual(before, Vault.fingerprint(path: link.path))
        try? fm.removeItem(at: base)
    }

    func testMissingVault() {
        XCTAssertFalse(Vault.load(path: "/nonexistent/vault").problems.isEmpty)
    }

    func testTildeExpands() {
        XCTAssertFalse(Vault.resolve("~/x").path.hasPrefix("~"))
    }
}
