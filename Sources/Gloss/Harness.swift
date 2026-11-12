import AppKit
import QuartzCore
import GlossCore
import SwiftUI

/// `--screenshot <file.png>` and `--self-test <file.json>`. Both use the made-up demo deck and keep
/// progress in memory only, so they never touch the vault or state.json.
@MainActor
enum Harness {
    final class Clock { var now: Date; init(_ d: Date) { now = d } }

    /// Harness windows are drawn far off-screen, so checks never flash a window on the person's screen.
    static let offscreen = NSPoint(x: -30_000, y: -30_000)

    static let demoVaultPath = "/Users/you/Notes/英文"

    static func demoSettings() -> AppSettings {
        let name = "app.gloss.harness"
        UserDefaults().removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: UserDefaults(suiteName: name)!)
        // A neutral path for pictures and recordings: never show the person's real vault location.
        settings.vaultPath = demoVaultPath
        return settings
    }

    /// Today at 10:00, outside the default quiet hours.
    static func demoMorning() -> Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
    }

    static func demoModel(_ clock: Clock) -> AppModel {
        AppModel(settings: demoSettings(), store: nil, fixedSnapshot: DemoDeck.snapshot, now: { clock.now })
    }

    /// A demo model with a made-up week of practice, so the overview tiles have something to show.
    static func demoModelWithHistory(_ clock: Clock) -> AppModel {
        let cal = Calendar.current
        let today = Day(clock.now, calendar: cal)
        var st = GlossState()
        let history: [(Int, Int)] = [(6, 4), (8, 7), (0, 0), (5, 4), (9, 8), (7, 6)]
        for (i, h) in history.enumerated() {
            st.daily[today.adding(days: -(history.count - i), calendar: cal).iso] = DailyStats(answered: h.0, correct: h.1)
        }
        st.cards["quintavel"] = CardState(box: 2, due: clock.now.addingTimeInterval(-3_600))
        st.cards["plexander"] = CardState(box: 1, due: clock.now.addingTimeInterval(-600))
        st.cards["zorbitude"] = CardState(box: 4, due: clock.now.addingTimeInterval(3 * 86_400))
        var snap = DemoDeck.snapshot
        snap.mistakes = MistakeParser.parse(DemoDeck.mistakes, day: today)
            + MistakeParser.parse("- `in monday` → `on Monday` — 星期幾用 on #介系詞\n- `a advice` → `advice` — 不可數 #冠詞", day: today.adding(days: -2, calendar: cal))
        return AppModel(settings: demoSettings(), store: nil, fixedSnapshot: snap, initialState: st, now: { clock.now })
    }

    static let sampleFix = FixResult(
        fixed: "I want to check the flumbrance of this server.",
        short: "Let me check this server's flumbrance.",
        mistakes: [
            .init(from: "flumberance", to: "flumbrance", why_zh: "中間沒有 e", category: "拼字"),
            .init(from: "want check", to: "want to check", why_zh: "want 後面要接 to + 原形動詞", category: "動詞形式"),
        ])

    // MARK: Screenshot

    struct Showcase: View {
        let home: AppModel
        let wrong: AppModel
        let windowModel: AppModel
        let router: Router
        let nav: Navigator

        static let windowSize = CGSize(width: 1000, height: 760)

        var body: some View {
            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 10) {
                    caption("Menu bar")
                    HStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "wifi")
                        MenuBarLabel(model: home)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .glass(Capsule(), strength: 0.1)
                        Text("10:00")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).frame(width: HomeView.width, height: 28)
                    .glass(Capsule(), strength: 0.02)
                    caption("Click the book icon: quick quiz")
                    popover(QuizView(onBack: {}).environmentObject(wrong).environmentObject(router))
                }
                VStack(alignment: .leading, spacing: 10) {
                    caption("The Gloss window: today's cards done, extra practice offered")
                    MainWindowView()
                        .environmentObject(windowModel)
                        .environmentObject(router)
                        .environmentObject(nav)
                        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
                        .background(Theme.wash)
                        .overlay(alignment: .topLeading) { trafficLights }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.15)))
                        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
                }
            }
            .padding(30)
            .background(AuroraBackdrop())
            .environment(\.simulatedGlass, true)
            .environment(\.colorScheme, .dark)
        }

        private var trafficLights: some View {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
            }
            .frame(width: 60, height: 12)
            .padding(.leading, 14).padding(.top, 14)
        }

        private func caption(_ s: String) -> some View {
            Text(s).font(.caption.weight(.bold)).foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 2)
        }

        /// The popover window's own glass around the quiz.
        private func popover<V: View>(_ v: V) -> some View {
            v.popoverChrome()
                .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
        }
    }

    static func runScreenshot(to path: String) {
        runApp {
            let clock = Clock(demoMorning())
            let home = demoModelWithHistory(clock)
            let wrong = demoModel(clock)
            wrong.answer = "flumberance"
            wrong.submit()
            // `--page <name>` draws only that page of the main window (to check one page).
            let args = CommandLine.arguments
            let onlyPage = args.firstIndex(of: "--page").flatMap { i in i + 1 < args.count ? Page(rawValue: args[i + 1]) : nil }
            // A model whose due cards are all answered, for the "keep practising" screen.
            let doneModel = demoModelWithHistory(clock)
            doneModel.openQuiz()
            while let c = doneModel.current {
                doneModel.answer = c.word
                doneModel.submit()
                doneModel.next()
            }
            let quizNav = Navigator()
            quizNav.page = .quiz
            let pageNav = Navigator()
            if let onlyPage { pageNav.page = onlyPage }
            let root: AnyView = onlyPage == nil
                ? AnyView(Showcase(home: home, wrong: wrong, windowModel: doneModel, router: Router(), nav: quizNav))
                : AnyView(MainWindowView().environmentObject(home).environmentObject(Router()).environmentObject(pageNav)
                    .frame(width: 1000, height: 760).background(Theme.wash).background(Theme.navy)
                    .environment(\.simulatedGlass, true).environment(\.colorScheme, .dark))
            let host = NSHostingView(rootView: root)
            host.frame.size = host.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: offscreen, size: host.frame.size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = Theme.darkAppearance
            window.contentView = host
            window.orderFrontRegardless()

            afterFrames(110) {
                // Fit again: the views fill in their data after the first layout.
                host.frame.size = host.fittingSize
                window.setContentSize(host.frame.size)
                host.layoutSubtreeIfNeeded()
            }
            afterFrames(120) {
                host.layoutSubtreeIfNeeded()
                let ok = savePNG(of: host, to: path)
                print(ok ? "Saved screenshot to \(path)" : "Could not save screenshot")
                exit(ok ? 0 : 1)
            }
        }
    }

    static func savePNG(of view: NSView, to path: String) -> Bool {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: url)) != nil
    }

    /// Share of pixels that differ clearly from the plain background: a blank picture gives about 0.
    static func inkRatio(of view: NSView) -> Double {
        let bg = NSColor(Theme.navy).usingColorSpace(.deviceRGB)!
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return 0 }
        view.cacheDisplay(in: view.bounds, to: rep)
        var ink = 0, total = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                total += 1
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   abs(c.redComponent - bg.redComponent) + abs(c.greenComponent - bg.greenComponent)
                    + abs(c.blueComponent - bg.blueComponent) > 0.25 { ink += 1 }
            }
        }
        return total == 0 ? 0 : Double(ink) / Double(total)
    }

    // MARK: Self-test

    struct Step: Codable { var step: String; var passed: Bool; var detail: String }
    struct Report: Codable { var version = 1; var steps: [Step] }

    static func runSelfTest(to path: String) {
        runApp {
            var steps: [Step] = []
            let clock = Clock(demoMorning())
            let model = demoModel(clock)
            model.openQuiz()

            // load: the demo deck parses; the real vault is only read (if it exists).
            let demoCount = model.entries.count
            let real = Vault.load(path: Vault.defaultPath)
            let realInfo = real.problems.isEmpty
                ? "real vault read-only: \(real.decks[.spelling]?.count ?? 0) spelling, \(real.decks[.usage]?.count ?? 0) word-choice cards, \(real.mistakes.count) mistake lines"
                : "real vault not checked (\(real.problems.joined(separator: "; ")))"
            steps.append(Step(step: "load", passed: demoCount == 5, detail: "demo deck: \(demoCount) cards; \(realInfo)"))

            // hud: badge number, the prompt text and a drawn quiz view.
            let first = model.current
            let prompt = first.map(CardPrompt.text(for:)) ?? "none"
            let host = NSHostingView(rootView: QuizView().environmentObject(model).environmentObject(Router())
                .background(Theme.navy)
                .environment(\.simulatedGlass, true)
                .environment(\.colorScheme, .dark))
            host.frame.size = host.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: offscreen, size: host.frame.size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            window.orderFrontRegardless()

            // window: every page of the one main window draws.
            let pageHosts: [(Page, NSHostingView<AnyView>)] = Page.allCases.map { page in
                let nav = Navigator()
                nav.page = page
                let pm = demoModelWithHistory(Clock(demoMorning()))
                let v = NSHostingView(rootView: AnyView(MainWindowView().environmentObject(pm).environmentObject(Router())
                    .environmentObject(nav).frame(width: 1000, height: 760).background(Theme.navy)
                    .environment(\.simulatedGlass, true).environment(\.colorScheme, .dark)))
                v.frame.size = CGSize(width: 1000, height: 760)
                let w = NSWindow(contentRect: NSRect(origin: offscreen, size: v.frame.size), styleMask: [.borderless],
                                 backing: .buffered, defer: false)
                w.contentView = v
                w.orderFrontRegardless()
                return (page, v)
            }

            // home: built now, measured after its fade-in animations have run.
            let hm = demoModelWithHistory(Clock(demoMorning()))
            let homeHost = NSHostingView(rootView: PopoverRoot().environmentObject(hm).environmentObject(Router())
                .background(Theme.navy).environment(\.simulatedGlass, true).environment(\.colorScheme, .dark))
            homeHost.frame.size = homeHost.fittingSize
            let homeWindow = NSWindow(contentRect: NSRect(origin: offscreen, size: homeHost.frame.size),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
            homeWindow.contentView = homeHost
            homeWindow.orderFrontRegardless()

            afterFrames(90) {
                let ink = inkRatio(of: host)
                let hudOK = model.dueCount == 5 && prompt == "容量 → f_________ (10)" && ink > 0.01
                steps.append(Step(step: "hud", passed: hudOK,
                                  detail: "badge shows \(model.dueCount) due; prompt “\(prompt)”; quiz view drawn (\(String(format: "%.1f", ink * 100))% ink)"))

                // act: a wrong answer shows the right spelling, marks the wrong letter and requeues the card.
                model.answer = "flumberance"
                model.submit()
                var actOK = false
                var actDetail = "no wrong-answer view"
                if case .wrong(let o) = model.phase {
                    let marked = zip(o.entry.word, o.wrongMask).filter(\.1).map { String($0.0) }.joined()
                    let st = model.state.cards[o.entry.word]
                    let dueIn = st.map { Int($0.due.timeIntervalSince(clock.now) / 60) } ?? -1
                    actOK = !o.correct && marked == "r" && st?.box == 1 && dueIn == 10 && !o.entry.hint.isEmpty
                    actDetail = "typed “flumberance”: shown “\(o.entry.word)”, wrong letter “\(marked)”, hint “\(o.entry.hint)”, box \(st?.box ?? 0), back in \(dueIn) min"
                }
                model.next()
                steps.append(Step(step: "act", passed: actOK, detail: actDetail))

                // move: a correct answer gives the green check and moves to the next card.
                let before = model.current
                let remainingBefore = model.sessionRemaining
                model.answer = "  " + (before?.word.uppercased() ?? "") + " "
                model.submit()
                let gotCheck: Bool
                if case .correct = model.phase { gotCheck = true } else { gotCheck = false }
                model.next()
                let after = model.current
                let moveOK = gotCheck && after != nil && after != before && model.sessionRemaining == remainingBefore - 1
                steps.append(Step(step: "move", passed: moveOK,
                                  detail: "answered “\(before?.word ?? "")” (case and spaces ignored) → green check → next card “\(after?.word ?? "none")”, \(model.sessionRemaining) left"))

                // requeue: the wrong card comes back later in the same round.
                var seen: [String] = []
                for _ in 0..<5 {
                    guard let c = model.current else { break }
                    seen.append(c.word)
                    model.answer = c.word
                    model.submit()
                    model.next()
                }
                let requeueOK = seen.contains("flumbrance") && model.phase == .done
                steps.append(Step(step: "requeue", passed: requeueOK, detail: "rest of the round: \(seen.joined(separator: ", "))"))

                // practice: after the day's cards are done, extra rounds still work and leave the schedule alone.
                let scheduleBefore = model.state.cards
                model.startPractice(.hardest)
                let practiceFirst = model.current
                model.answer = practiceFirst?.word ?? ""
                model.submit()
                model.next()
                let practicedToday = model.state.stats(for: model.today).practiced
                let practiceOK = model.isPracticing && practiceFirst != nil && model.state.cards == scheduleBefore
                    && practicedToday == 1 && model.practiceCount(.today) == 5
                let extraBefore = model.state.stats(for: model.today).extraNew
                model.learnMoreNew()
                let extraOK = model.state.stats(for: model.today).extraNew == extraBefore + Practice.roundSize && !model.isPracticing
                steps.append(Step(step: "practice", passed: practiceOK && extraOK,
                                  detail: "after all cards were done: practice round “hardest” starts with “\(practiceFirst?.word ?? "none")”; answering it left every box and due time unchanged; \(practicedToday) practice answer counted; “Today's words” offers \(model.practiceCount(.today)); “Learn more” raised today's new-card limit by \(Practice.roundSize)"))

                // schedule: answered correctly today → not due again today; due again tomorrow.
                let w = before?.word ?? ""
                clock.now = clock.now.addingTimeInterval(3_600)
                let dueLater = model.dueCards().contains { $0.word == w }
                clock.now = Calendar.current.date(byAdding: .day, value: 1, to: clock.now)!
                let dueTomorrow = model.dueCards().contains { $0.word == w }
                steps.append(Step(step: "schedule", passed: !dueLater && dueTomorrow,
                                  detail: "“\(w)” due 1 h later: \(dueLater); due tomorrow: \(dueTomorrow) (box 1 → 10 min, 1 day after a correct answer)"))

                // pronounce: the speaker button and the spoken answer (muted here; what would be said is recorded).
                model.startSession()
                let spokenBefore = Pronouncer.shared.spokenCount
                model.pronounceCurrent()
                let buttonSaid = Pronouncer.shared.lastSpoken
                let cardWord = model.current?.word
                model.answer = "zzz"
                model.submit()
                let answerSaid = Pronouncer.shared.lastSpoken
                let pronounceOK = cardWord != nil && buttonSaid == cardWord && answerSaid == cardWord
                    && Pronouncer.shared.spokenCount == spokenBefore + 2
                steps.append(Step(step: "pronounce", passed: pronounceOK,
                                  detail: "speaker button says “\(buttonSaid ?? "nothing")”; after an answer it says “\(answerSaid ?? "nothing")” (en-US system voice, \(Pronouncer.rateFactor)× speed)"))

                let pageInk = pageHosts.map { ($0.0, inkRatio(of: $0.1)) }
                let pagesOK = pageInk.allSatisfy { $0.1 > 0.05 }
                steps.append(Step(step: "window", passed: pagesOK,
                                  detail: "one main window with \(Page.allCases.count) pages: " + pageInk.map { "\($0.0.title) \(String(format: "%.0f", $0.1 * 100))%" }.joined(separator: ", ") + " ink"))

                // home: the overview tiles and recommendation, and Start Quiz switching to the quiz.
                let homeInk = inkRatio(of: homeHost)
                let rec = hm.recommendation(fixShortcut: "⌃⌥E")
                let wk = hm.weekAnswers
                hm.showingQuiz = true
                let homeOK = hm.health != .gettingStarted && hm.streak.current == 3 && rec.action == .quiz
                    && hm.boxCounts.reduce(0, +) == 5 && homeInk > 0.05 && hm.showingQuiz
                steps.append(Step(step: "home", passed: homeOK,
                                  detail: "English Health: \(hm.health.rawValue) (\(wk.correct)/\(wk.answered) in 7 days); streak \(hm.streak.current); boxes \(hm.boxCounts); recommendation “\(rec.title)”; Start Quiz opens the quiz; overview drawn (\(String(format: "%.0f", homeInk * 100))% ink)"))

                // fix_json and nudge: the parts of the hotkey and reminders that run without other apps.
                let parsed = try? FixPrompt.parse("```json\n{\"fixed\":\"He goes.\",\"short\":\"He goes.\",\"mistakes\":[]}\n```")
                steps.append(Step(step: "fix_json", passed: parsed?.fixed == "He goes.", detail: "claude reply parsed: \(parsed?.fixed ?? "failed")"))
                let cal = Calendar.current
                let night = cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
                let day = cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
                let n1 = NudgePolicy.shouldNudge(now: day, lastNudge: nil, intervalMinutes: 60, dueCount: 3, quiet: .default, calendar: cal)
                let n2 = NudgePolicy.shouldNudge(now: night, lastNudge: nil, intervalMinutes: 60, dueCount: 3, quiet: .default, calendar: cal)
                steps.append(Step(step: "nudge", passed: n1 && !n2, detail: "10:00 → nudge \(n1); 23:00 (quiet hours) → nudge \(n2)"))

                // focus: after a right answer the next card can be typed without clicking.
                focusCheck { step in
                    steps.append(step)
                    typingCheck { typed in
                    steps.append(typed)
                    drillCheck { drilled in
                    steps.append(drilled)
                    steps.append(addWordCheck())
                    warmClaudeCheck { warm in
                    steps.append(warm)
                    idleCpuCheck { cpu in
                    steps.append(cpu)
                    let enc = JSONEncoder()
                    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                    let url = URL(fileURLWithPath: path)
                    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? enc.encode(Report(steps: steps)).write(to: url)
                    for s in steps { print("\(s.passed ? "PASS" : "FAIL") \(s.step): \(s.detail)") }
                    exit(steps.allSatisfy(\.passed) ? 0 : 1)
                    }
                    }
                    }
                    }
                }
            }
        }
    }

    /// Opens the quiz in a real (off-screen, key) window and checks where the cursor is after each card.
    private static func focusCheck(done: @escaping (Step) -> Void) {
        let clock = Clock(demoMorning())
        let m = demoModel(clock)
        let host = NSHostingView(rootView: QuizView(width: 480, showsFooter: false).environmentObject(m).environmentObject(Router())
            .environment(\.colorScheme, .dark))
        host.frame.size = CGSize(width: 480, height: 520)
        let w = KeyablePanel(contentRect: NSRect(origin: offscreen, size: host.frame.size),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = host
        w.orderFrontRegardless()
        w.makeKey()

        func cursorInField() -> Bool {
            if let tv = w.firstResponder as? NSTextView { return tv.isFieldEditor }
            return w.firstResponder is NSTextField
        }

        afterFrames(30) {
            let atStart = cursorInField()
            let first = m.current
            m.answer = first?.word ?? ""
            m.submit()                                  // right answer → green check, then the next card by itself
            afterFrames(Int(AppModel.correctPause * 60) + 30) {
                let second = m.current
                let afterCorrect = cursorInField()
                m.answer = "zzz"
                m.submit()                              // wrong answer
                m.submit()                              // Enter again → next card
                afterFrames(30) {
                    let afterWrong = cursorInField()
                    let third = m.current
                    m.answer = third?.word ?? ""
                    m.submit()                          // right; now type during the green-check pause
                    m.answer = "q"
                    let typedThrough = m.phase == .asking && m.answer == "q" && m.current != third
                    afterFrames(30) {
                        let ok = atStart && afterCorrect && afterWrong && typedThrough && second != first
                        done(Step(step: "focus", passed: ok,
                                  detail: "cursor in the answer field: at start \(atStart), after a right answer \(afterCorrect), after a wrong answer + Enter \(afterWrong); typing during the green check went to the next card keeping “q”: \(typedThrough)"))
                    }
                }
            }
        }
    }

    /// Types each answer through the text field (as the keyboard does), presses Enter, and checks that every
    /// right answer moves on to the next card by itself.
    static func typingCheck(rounds: Int = 5, done: @escaping (Step) -> Void) {
        let clock = Clock(demoMorning())
        let m = demoModel(clock)
        let host = NSHostingView(rootView: QuizView(width: 480, showsFooter: false).environmentObject(m).environmentObject(Router())
            .environment(\.colorScheme, .dark))
        host.frame.size = CGSize(width: 480, height: 560)
        let w = KeyablePanel(contentRect: NSRect(origin: offscreen, size: host.frame.size),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = host
        w.orderFrontRegardless()
        w.makeKey()
        var log: [String] = []
        var ok = true

        func round(_ i: Int) {
            guard i < rounds, let card = m.current else {
                done(Step(step: "auto-next", passed: ok && log.count == rounds,
                          detail: "typed and pressed Enter for \(log.count) right answers: " + log.joined(separator: ", ")))
                return
            }
            guard let editor = w.firstResponder as? NSTextView, editor.isFieldEditor else {
                ok = false
                log.append("\(card.word): no cursor in the field")
                done(Step(step: "auto-next", passed: false, detail: log.joined(separator: ", ")))
                return
            }
            editor.insertText(card.word, replacementRange: editor.selectedRange())
            editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
            afterFrames(Int(AppModel.correctPause * 60) + 24) {
                let moved = m.current != card && (m.phase == .asking || m.phase == .done)
                if !moved { ok = false }
                log.append("\(card.word) → \(moved ? (m.current?.word ?? "done") : "STUCK (\(m.phase))")")
                if moved { round(i + 1) } else {
                    done(Step(step: "auto-next", passed: false, detail: log.joined(separator: ", ")))
                }
            }
        }
        afterFrames(30) { round(0) }
    }

    /// Wrong answer, then the copy drill through the text field: a bad copy does not count, three right
    /// copies finish it, and the next card comes by itself.
    static func drillCheck(done: @escaping (Step) -> Void) {
        let clock = Clock(demoMorning())
        let m = demoModel(clock)
        m.settings.copyReps = 3
        let host = NSHostingView(rootView: QuizView(width: 480, showsFooter: false).environmentObject(m).environmentObject(Router())
            .environment(\.colorScheme, .dark))
        host.frame.size = CGSize(width: 480, height: 640)
        let w = KeyablePanel(contentRect: NSRect(origin: offscreen, size: host.frame.size),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = host
        w.orderFrontRegardless()
        w.makeKey()

        func type(_ text: String) -> Bool {
            guard let editor = w.firstResponder as? NSTextView, editor.isFieldEditor else { return false }
            editor.insertText(text, replacementRange: editor.selectedRange())
            editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
            return true
        }

        afterFrames(30) {
            guard let card = m.current else { done(Step(step: "copy-drill", passed: false, detail: "no card")); return }
            let word = card.word
            var notes: [String] = []
            _ = type("x" + word)                                    // wrong answer
            let started = m.drill?.required == 3 && m.answer.isEmpty
            notes.append("wrong answer → drill of \(m.drill?.required ?? 0), field cleared \(m.answer.isEmpty)")
            afterFrames(12) {
                _ = type(String(word.dropLast()))                    // a copy with a mistake
                let missOK = m.drill?.done == 0 && m.drillMisses == 1
                notes.append("bad copy → \(m.drill?.done ?? -1) counted, \(m.drillMisses) miss")
                afterFrames(12) {
                    var typedAll = true
                    for _ in 0..<3 { typedAll = typedAll && type(word) }
                    let finished = m.drill?.isFinished == true
                    notes.append("3 right copies → finished \(finished)")
                    afterFrames(Int(AppModel.drillDonePause * 60) + 24) {
                        let moved = m.current != card && m.phase == .asking && m.drill == nil
                        notes.append("then the next card by itself: \(moved ? m.current?.word ?? "-" : "no")")
                        done(Step(step: "copy-drill", passed: started && missOK && typedAll && finished && moved,
                                  detail: "“\(word)”: " + notes.joined(separator: "; ")))
                    }
                }
            }
        }
    }

    /// `--cpu-check`: only the idle-CPU measurement (GLOSS_HOLD=1 waits 20 s after hiding, for sampling).
    static func runCpuCheck() {
        runApp {
            idleCpuCheck { step in
                print("\(step.passed ? "PASS" : "FAIL") \(step.step): \(step.detail)")
                let hold = ProcessInfo.processInfo.environment["GLOSS_HOLD"] != nil ? 20.0 : 0
                DispatchQueue.main.asyncAfter(deadline: .now() + hold) { exit(step.passed ? 0 : 1) }
            }
        }
    }

    /// Adding new words: into a temporary vault's ## 問過的字 table when writing to notes is on, else into
    /// Gloss's own list; duplicates are refused; the words join the deck and can be practised at once.
    static func addWordCheck() -> Step {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("gloss-addword-\(UUID().uuidString)")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let note = DemoDeck.markdown + "\n\n## 問過的字\n\n| 字 | 中文 | 例句 |\n|---|---|---|\n| quorble | 抱怨 | Don't quorble. |\n"
        let vocab = dir.appendingPathComponent(Vault.vocabFile)
        try? note.write(to: vocab, atomically: true, encoding: .utf8)
        let settings = demoSettings()
        settings.vaultPath = dir.path
        settings.saveFixMistakes = true
        let m = AppModel(settings: settings, store: nil, wordStore: NewWordStore(url: dir.appendingPathComponent("words.json")),
                         now: { demoMorning() })
        var notes: [String] = []
        let a = m.addWord("zelquin", meaning: "微調", example: "Please zelquin the config.")
        let inFile = (try? String(contentsOf: vocab, encoding: .utf8))?.contains("| zelquin | 微調 | Please zelquin the config. |") ?? false
        notes.append("to notes: \(a == .savedToNotes ? "saved" : "\(a)"), row in 單字.md \(inFile)")
        let b = m.addWord("Zelquin", meaning: "x", example: "")
        notes.append("again: \(b == .alreadyInNotes ? "refused as a duplicate" : "\(b)")")
        settings.saveFixMistakes = false
        let c = m.addWord("plimbo", meaning: "小狗", example: "")
        let kept = NewWordStore(url: dir.appendingPathComponent("words.json")).load().map(\.word)
        notes.append("notes off: \(c == .savedInGloss(note: nil) ? "kept in Gloss" : "\(c)") \(kept)")
        let deck = m.newWords.map(\.word)
        notes.append("New words deck: \(deck)")
        m.practise(m.newWords)
        let practising = m.isPracticing && m.current.map { deck.contains($0.word) } == true
        notes.append("practise now: \(practising)")
        let ok = a == .savedToNotes && inFile && b == .alreadyInNotes && c == .savedInGloss(note: nil)
            && kept == ["plimbo"] && Set(deck) == ["quorble", "zelquin", "plimbo"] && practising
        return Step(step: "add-word", passed: ok, detail: notes.joined(separator: "; "))
    }

    /// The waiting Claude, with a stand-in `claude` script (1 s to start, then answers at once): it is
    /// started ahead, answers a look-up and a fix quickly, and the next one is started after each answer.
    static func warmClaudeCheck(done: @escaping (Step) -> Void) {
        let fm = FileManager.default
        let script = fm.temporaryDirectory.appendingPathComponent("gloss-fake-claude-\(UUID().uuidString).py")
        let source = """
        #!/usr/bin/env python3
        import sys, json, time
        time.sleep(1.0)
        print(json.dumps({"type": "system", "subtype": "init"}), flush=True)
        for line in sys.stdin:
            try:
                text = json.loads(line)["message"]["content"]
            except Exception:
                continue
            if "met an English word" in text:
                res = json.dumps({"word": "zelquin", "meaning_zh": "微調", "example": "Please zelquin it."})
            else:
                res = json.dumps({"fixed": "He goes home.", "short": "He goes.", "mistakes": []})
            print(json.dumps({"type": "result", "subtype": "success", "is_error": False, "result": res}), flush=True)
        """
        try? source.write(to: script, atomically: true, encoding: .utf8)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let saved = (ClaudeRunner.override, ClaudeRunner.keepWarm, ClaudeRunner.model)
        ClaudeRunner.stopSpare()
        ClaudeRunner.override = (script.path, ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin")
        ClaudeRunner.keepWarm = true
        ClaudeRunner.model = "haiku"
        ClaudeRunner.prewarm()

        Task { @MainActor in
            var notes: [String] = []
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let readyFirst = ClaudeRunner.isReady
            notes.append("ready ahead: \(readyFirst)")
            var ok = readyFirst
            let t0 = Date()
            if let r = try? await ClaudeRunner.lookUp("zelqin") {
                let dt = Date().timeIntervalSince(t0)
                notes.append(String(format: "look-up “%@” → “%@” %@ in %.2f s", "zelqin", r.word, r.meaning_zh, dt))
                ok = ok && r.word == "zelquin" && dt < 0.8
            } else { ok = false; notes.append("look-up failed") }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let readyAgain = ClaudeRunner.isReady
            notes.append("next one ready: \(readyAgain)")
            let t1 = Date()
            if let f = try? await ClaudeRunner.fix("He go home.") {
                let dt = Date().timeIntervalSince(t1)
                notes.append(String(format: "fix → “%@” in %.2f s", f.fixed, dt))
                ok = ok && readyAgain && f.fixed == "He goes home." && dt < 0.8
            } else { ok = false; notes.append("fix failed") }
            ClaudeRunner.stopSpare()
            (ClaudeRunner.override, ClaudeRunner.keepWarm, ClaudeRunner.model) = saved
            try? fm.removeItem(at: script)
            done(Step(step: "claude-warm", passed: ok, detail: notes.joined(separator: "; ")))
        }
    }

    /// `--claude-check [model]`: the real Claude, warmed first; times a word look-up and a fix.
    static func runClaudeCheck(model: String) {
        runApp {
            ClaudeRunner.model = model
            ClaudeRunner.keepWarm = true
            let tCold = Date()
            ClaudeRunner.prewarm()
            Task { @MainActor in
                while !ClaudeRunner.isReady && Date().timeIntervalSince(tCold) < 30 { try? await Task.sleep(nanoseconds: 100_000_000) }
                print(String(format: "Claude ready after %.1f s (model %@)", Date().timeIntervalSince(tCold), model))
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                var t = Date()
                do {
                    let r = try await ClaudeRunner.lookUp("serendipitous")
                    print(String(format: "look-up: %.1f s → %@ | %@ | %@", Date().timeIntervalSince(t), r.word, r.meaning_zh, r.example))
                } catch { print("look-up failed: \(error.localizedDescription)") }
                while !ClaudeRunner.isReady { try? await Task.sleep(nanoseconds: 100_000_000) }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                t = Date()
                do {
                    let f = try await ClaudeRunner.fix("I want check the logs of this server yesterday, it have many error.")
                    print(String(format: "fix: %.1f s → %@ | %@ | %d mistakes: %@", Date().timeIntervalSince(t), f.fixed, f.short,
                                 f.mistakes.count, f.mistakes.map { "\($0.from)→\($0.to) #\($0.category) \($0.why_zh)" }.joined(separator: "; ")))
                } catch { print("fix failed: \(error.localizedDescription)") }
                ClaudeRunner.stopSpare()
                exit(0)
            }
        }
    }

    /// CPU time this process used, in seconds (user + system).
    static func cpuSeconds() -> Double {
        var u = rusage()
        getrusage(RUSAGE_SELF, &u)
        return Double(u.ru_utime.tv_sec) + Double(u.ru_utime.tv_usec) / 1e6
            + Double(u.ru_stime.tv_sec) + Double(u.ru_stime.tv_usec) / 1e6
    }

    /// The main window with its drifting wash and floating logo: shown (nearly invisible, never clickable),
    /// then hidden as when it is closed. Measures CPU in both states; hidden must be close to zero.
    static func idleCpuCheck(done: @escaping (Step) -> Void) {
        // Tear down the earlier steps' test windows first, so only this window is measured.
        for old in NSApp.windows {
            old.contentView = nil
            old.orderOut(nil)
        }
        let m = demoModelWithHistory(Clock(demoMorning()))
        m.settings.welcomeDone = true
        let host = NSHostingView(rootView: MainWindowView().environmentObject(m).environmentObject(Router())
            .environmentObject(Navigator()).background(AnimatedWash()).trackWindowVisibility()
            .environment(\.colorScheme, .dark))
        host.frame.size = CGSize(width: 900, height: 640)
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let w = KeyablePanel(contentRect: NSRect(x: screen.minX, y: screen.minY, width: 900, height: 640),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = host
        w.alphaValue = 0.01          // on screen so it counts as visible, but not noticeable
        w.ignoresMouseEvents = true
        w.level = .normal
        w.orderFrontRegardless()     // in front and key, as when the person is using it (1% opaque, no clicks or keys)
        w.makeKey()

        func measure(_ seconds: Double, _ then: @escaping (Double) -> Void) {
            let t0 = cpuSeconds(), start = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                then((cpuSeconds() - t0) / Date().timeIntervalSince(start) * 100)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let keyWhenShown = w.isKeyWindow && w.occlusionState.contains(.visible)
            measure(4) { shown in
                w.orderOut(nil)                       // what closing the window does
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    measure(6) { hidden in
                        done(Step(step: "idle-cpu", passed: hidden < 1.5,
                                  detail: String(format: "main window in use (key: %@): %.1f%% CPU; after it is closed: %.1f%% CPU (must be under 1.5%%)",
                                                 keyWhenShown ? "yes" : "no", shown, hidden)))
                    }
                }
            }
        }
    }

    // MARK: Run loop helpers

    private final class Launcher: NSObject, NSApplicationDelegate {
        let work: () -> Void
        init(_ work: @escaping () -> Void) { self.work = work }
        func applicationDidFinishLaunching(_ notification: Notification) { work() }
    }
    private static var launcher: Launcher?

    private static func runApp(_ work: @escaping () -> Void) {
        Pronouncer.shared.muted = true
        let app = NSApplication.shared
        app.appearance = Theme.darkAppearance
        app.setActivationPolicy(.accessory)
        launcher = Launcher(work)
        app.delegate = launcher
        app.run()
    }

    /// Runs `body` after about `n` frames at 60 fps, letting SwiftUI lay out and draw.
    private static func afterFrames(_ n: Int, _ body: @escaping () -> Void) {
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { t in
            count += 1
            if count >= n {
                t.invalidate()
                MainActor.assumeIsolated { body() }
            }
        }
    }
}
