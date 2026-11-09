import AppKit
import GlossCore
import SwiftUI

/// `--record <folder> --scene <name>`: plays a scripted scene off-screen with the made-up demo deck and
/// writes frame-0000.tiff… plus times.txt (milliseconds since the start of each frame), for the README's
/// animated pictures (scripts/record-demos.sh). Capturing is slower than 30 fps, so the real times are kept
/// and the animation plays back at its true speed.
@MainActor
enum Recorder {
    static let fps = 30

    struct Scene {
        var size: CGSize
        var duration: Double
        var view: AnyView
        /// (seconds from start, action)
        var script: [(Double, () -> Void)]
    }

    static func run(folder: String, scene name: String) {
        Pronouncer.shared.muted = true
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = Theme.darkAppearance
        launcher = Launcher {
            guard let scene = makeScene(name) else { print("unknown scene \(name)"); exit(2) }
            let url = URL(fileURLWithPath: folder)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let host = NSHostingView(rootView: scene.view
                .environment(\.simulatedGlass, true)
                .environment(\.colorScheme, .dark))
            host.frame.size = scene.size
            let window = KeyablePanel(contentRect: NSRect(origin: Harness.offscreen, size: scene.size),
                                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.appearance = Theme.darkAppearance
            window.contentView = host
            window.orderFrontRegardless()
            window.makeKey()

            var pending = scene.script.sorted { $0.0 < $1.0 }
            let start = Date()
            var frame = 0
            var times: [String] = []
            Timer.scheduledTimer(withTimeInterval: 1.0 / Double(fps), repeats: true) { t in
                MainActor.assumeIsolated {
                    let elapsed = Date().timeIntervalSince(start)
                    while let first = pending.first, first.0 <= elapsed {
                        pending.removeFirst()
                        first.1()
                    }
                    host.layoutSubtreeIfNeeded()
                    if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                        host.cacheDisplay(in: host.bounds, to: rep)
                        let file = url.appendingPathComponent(String(format: "frame-%04d.tiff", frame))
                        try? rep.tiffRepresentation?.write(to: file)
                        times.append(String(Int(elapsed * 1000)))
                        frame += 1
                    }
                    if elapsed >= scene.duration {
                        t.invalidate()
                        try? (times.joined(separator: "\n") + "\n").write(to: url.appendingPathComponent("times.txt"), atomically: true, encoding: .utf8)
                        print("Wrote \(frame) frames over \(String(format: "%.1f", elapsed)) s to \(folder)")
                        exit(0)
                    }
                }
            }
        }
        app.delegate = launcher
        app.run()
    }

    private final class Launcher: NSObject, NSApplicationDelegate {
        let work: () -> Void
        init(_ work: @escaping () -> Void) { self.work = work }
        func applicationDidFinishLaunching(_ notification: Notification) { work() }
    }
    private static var launcher: Launcher?

    /// Types `text` into the model one letter at a time, starting at `at` seconds.
    private static func typing(_ text: String, into m: AppModel, at: Double, every: Double = 0.11) -> [(Double, () -> Void)] {
        var steps: [(Double, () -> Void)] = []
        var typed = ""
        for (i, ch) in text.enumerated() {
            typed.append(ch)
            let now = typed
            steps.append((at + Double(i) * every, { m.answer = now }))
        }
        return steps
    }

    /// A popover-shaped frame with the violet wash, as the menu bar shows it.
    private static func popover<V: View>(_ v: V) -> some View {
        v.popoverChrome()
            .padding(24)
            .background(AuroraBackdrop())
    }

    private static func makeScene(_ name: String) -> Scene? {
        let clock = Harness.Clock(Harness.demoMorning())
        let router = Router()
        switch name {
        case "quiz":
            let m = Harness.demoModel(clock)
            m.openQuiz()
            var script: [(Double, () -> Void)] = []
            script += typing("flumbrance", into: m, at: 0.6)
            script.append((1.85, { m.submit() }))             // right → sparks, then the next card slides in
            script += typing("quintivel", into: m, at: 3.2)
            script.append((4.4, { m.submit() }))              // wrong → shake, right spelling, hint
            script.append((7.0, { m.submit() }))              // Enter → next card
            script += typing("zorbitude", into: m, at: 7.6)
            script.append((8.8, { m.submit() }))
            return Scene(size: CGSize(width: HomeView.width + 48, height: 560), duration: 10.2,
                         view: AnyView(popover(QuizView(showsFooter: true).environmentObject(m).environmentObject(router))),
                         script: script)
        case "overview":
            let m = Harness.demoModelWithHistory(clock)
            m.settings.welcomeDone = true
            return Scene(size: CGSize(width: HomeView.width + 48, height: 760), duration: 3.4,
                         view: AnyView(popover(HomeView(startQuiz: {}).environmentObject(m).environmentObject(router))),
                         script: [])
        case "fix":
            let fix = FixModel()
            let text = "I want check the flumberance of this server."
            fix.phase = .copying
            return Scene(size: CGSize(width: 460 + 48, height: 600), duration: 5.0,
                         view: AnyView(FixView(model: fix).padding(24).frame(width: 460 + 48, height: 600, alignment: .top)
                            .background(AuroraBackdrop())),
                         script: [
                            (0.7, { withAnimation(Motion.spring) { fix.phase = .asking(text) } }),
                            (2.2, { withAnimation(Motion.spring) { fix.phase = .done(text, Harness.sampleFix) } }),
                            (3.9, { fix.copied = "Fixed" }),
                         ])
        case "window", "practice":
            let m = Harness.demoModelWithHistory(clock)
            m.settings.welcomeDone = true
            let nav = Navigator()
            var script: [(Double, () -> Void)] = []
            if name == "window" {
                for (t, p) in [(1.6, Page.quiz), (3.4, Page.stats), (5.6, Page.fix), (7.0, Page.settings), (8.6, Page.overview)] {
                    script.append((t, { withAnimation(Motion.spring) { nav.page = p } }))
                }
            } else {
                // Finish the day's cards, then pick "Hardest 10" and answer one.
                m.openQuiz()
                while let c = m.current { m.answer = c.word; m.submit(); m.next() }
                nav.page = .quiz
                script.append((1.6, { m.startPractice(.hardest) }))
                if let first = Practice.pick(.hardest, from: m.entries, states: m.state.cards, today: m.today,
                                             calendar: m.calendar, seed: 1).first {
                    script += typing(first.word, into: m, at: 2.6)
                    script.append((2.6 + Double(first.word.count) * 0.11 + 0.3, { m.submit() }))
                }
            }
            let view = MainWindowView()
                .environmentObject(m).environmentObject(router).environmentObject(nav)
                .frame(width: 1000, height: 700)
                .background(Theme.wash) // still background: a drifting one makes every frame differ (big file)
                .background(Theme.navy)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            return Scene(size: CGSize(width: 1000, height: 700), duration: name == "window" ? 10.4 : 5.6,
                         view: AnyView(view), script: script)
        default:
            return nil
        }
    }
}
