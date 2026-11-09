import AppKit
import GlossCore
import SwiftUI

/// `--screenshot <file.png>` and `--self-test <file.json>`. Both use the made-up demo deck and keep
/// progress in memory only, so they never touch the vault or state.json.
@MainActor
enum Harness {
    final class Clock { var now: Date; init(_ d: Date) { now = d } }

    static func demoSettings() -> AppSettings {
        let name = "app.gloss.harness"
        UserDefaults().removePersistentDomain(forName: name)
        return AppSettings(defaults: UserDefaults(suiteName: name)!)
    }

    /// Today at 10:00, outside the default quiet hours.
    static func demoMorning() -> Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
    }

    static func demoModel(_ clock: Clock) -> AppModel {
        AppModel(settings: demoSettings(), store: nil, fixedSnapshot: DemoDeck.snapshot, now: { clock.now })
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
        let asking: AppModel
        let wrong: AppModel
        let router: Router
        let fix: FixModel

        var body: some View {
            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    caption("Menu bar")
                    HStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "wifi")
                        MenuBarLabel(model: asking)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.12)))
                        Text("10:00")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 10).frame(width: QuizView.width, height: 24)
                    .background(Color(white: 0.93))
                    caption("Quiz")
                    panel(QuizView().environmentObject(asking).environmentObject(router))
                }
                VStack(alignment: .leading, spacing: 8) {
                    caption("After a wrong answer")
                    panel(QuizView().environmentObject(wrong).environmentObject(router))
                }
                VStack(alignment: .leading, spacing: 8) {
                    caption("Fix my English (⌃⌥E)")
                    panel(FixView(model: fix))
                }
            }
            .padding(24)
            .background(LinearGradient(colors: [Color(red: 0.86, green: 0.90, blue: 0.97), Color(red: 0.95, green: 0.93, blue: 0.98)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .environment(\.colorScheme, .light)
        }

        private func caption(_ s: String) -> some View {
            Text(s).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }

        private func panel<V: View>(_ v: V) -> some View {
            v.background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08)))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
    }

    static func runScreenshot(to path: String) {
        runApp {
            let clock = Clock(demoMorning())
            let asking = demoModel(clock)
            let wrong = demoModel(clock)
            wrong.answer = "flumberance"
            wrong.submit()
            let fix = FixModel()
            fix.phase = .done("I want check the flumberance of this server.", sampleFix)

            let host = NSHostingView(rootView: Showcase(asking: asking, wrong: wrong, router: Router(), fix: fix))
            host.frame.size = host.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: 40, y: 40), size: host.frame.size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = host
            window.orderFrontRegardless()

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

    /// Share of pixels that are not near-white: a blank picture gives about 0.
    static func inkRatio(of view: NSView) -> Double {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return 0 }
        view.cacheDisplay(in: view.bounds, to: rep)
        var ink = 0, total = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                total += 1
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   c.alphaComponent > 0.5, c.redComponent + c.greenComponent + c.blueComponent < 2.6 { ink += 1 }
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
            let host = NSHostingView(rootView: QuizView().environmentObject(model).environmentObject(Router()))
            host.frame.size = host.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: .init(x: 40, y: 40), size: host.frame.size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            window.orderFrontRegardless()

            afterFrames(60) {
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

                // schedule: answered correctly today → not due again today; due again tomorrow.
                let w = before?.word ?? ""
                clock.now = clock.now.addingTimeInterval(3_600)
                let dueLater = model.dueCards().contains { $0.word == w }
                clock.now = Calendar.current.date(byAdding: .day, value: 1, to: clock.now)!
                let dueTomorrow = model.dueCards().contains { $0.word == w }
                steps.append(Step(step: "schedule", passed: !dueLater && dueTomorrow,
                                  detail: "“\(w)” due 1 h later: \(dueLater); due tomorrow: \(dueTomorrow) (box 1 → 10 min, 1 day after a correct answer)"))

                // fix_json and nudge: the parts of the hotkey and reminders that run without other apps.
                let parsed = try? FixPrompt.parse("```json\n{\"fixed\":\"He goes.\",\"short\":\"He goes.\",\"mistakes\":[]}\n```")
                steps.append(Step(step: "fix_json", passed: parsed?.fixed == "He goes.", detail: "claude reply parsed: \(parsed?.fixed ?? "failed")"))
                let cal = Calendar.current
                let night = cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
                let day = cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
                let n1 = NudgePolicy.shouldNudge(now: day, lastNudge: nil, intervalMinutes: 60, dueCount: 3, quiet: .default, calendar: cal)
                let n2 = NudgePolicy.shouldNudge(now: night, lastNudge: nil, intervalMinutes: 60, dueCount: 3, quiet: .default, calendar: cal)
                steps.append(Step(step: "nudge", passed: n1 && !n2, detail: "10:00 → nudge \(n1); 23:00 (quiet hours) → nudge \(n2)"))

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

    // MARK: Run loop helpers

    private final class Launcher: NSObject, NSApplicationDelegate {
        let work: () -> Void
        init(_ work: @escaping () -> Void) { self.work = work }
        func applicationDidFinishLaunching(_ notification: Notification) { work() }
    }
    private static var launcher: Launcher?

    private static func runApp(_ work: @escaping () -> Void) {
        let app = NSApplication.shared
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
