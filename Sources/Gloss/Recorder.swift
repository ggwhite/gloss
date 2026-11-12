import AppKit
import GlossCore
import SwiftUI

/// `--record <folder> --scene <name>`: plays a scripted scene off-screen with the made-up demo deck and
/// writes frame-0000.tiff… plus times.txt (milliseconds since the start of each frame), for the README's
/// animated pictures (scripts/record-demos.sh). One snapshot takes 20–190 ms (mostly drawing blurred
/// shadows on the CPU), so the whole scene runs `timeScale` times slower (`Motion.timeScale`: animations,
/// pauses, the drifting wash and the script) and times.txt holds scene time: the result plays at true
/// speed with `fps` frames a second.
@MainActor
enum Recorder {
    static let fps = 30
    static let timeScale: Double = 4

    struct Scene {
        var size: CGSize
        /// Snapshot pixels per point, whatever the display: the README shows the 1000 pt window at 820 px,
        /// and fewer pixels make each snapshot quicker.
        var scale: CGFloat = 1
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
        Motion.timeScale = timeScale
        launcher = Launcher {
            guard let scene = makeScene(name) else { print("unknown scene \(name)"); exit(2) }
            let url = URL(fileURLWithPath: folder)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let host = NSHostingView(rootView: scene.view
                .environment(\.simulatedGlass, true)
                .environment(\.colorScheme, .dark))
            host.frame.size = scene.size
            let window = KeyablePanel(contentRect: NSRect(origin: Harness.offscreen, size: scene.size),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = Theme.darkAppearance
            window.contentView = host
            window.orderFrontRegardless()
            window.makeKey()

            var pending = scene.script.sorted { $0.0 < $1.0 }
            let start = Date()
            var frame = 0
            var times: [String] = []
            var nextFrame = 0.0
            // Checks often and snaps as soon as a frame is due: a slow snapshot then delays only the next one,
            // where a timer at the frame rate would skip a whole tick.
            Timer.scheduledTimer(withTimeInterval: 0.005, repeats: true) { t in
                MainActor.assumeIsolated {
                    let elapsed = Date().timeIntervalSince(start) / timeScale   // scene time
                    while let first = pending.first, first.0 <= elapsed {
                        pending.removeFirst()
                        first.1()
                    }
                    guard elapsed >= nextFrame || elapsed >= scene.duration else { return }
                    nextFrame = max(nextFrame + 1 / Double(fps), elapsed - 1 / Double(fps))   // catch up one late frame, no more
                    host.layoutSubtreeIfNeeded()
                    if let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(scene.size.width * scene.scale),
                                                  pixelsHigh: Int(scene.size.height * scene.scale), bitsPerSample: 8,
                                                  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                                  bytesPerRow: 0, bitsPerPixel: 0)?.retagging(with: .sRGB) {
                        rep.size = scene.size
                        host.cacheDisplay(in: host.bounds, to: rep)
                        let file = url.appendingPathComponent(String(format: "frame-%04d.tiff", frame))
                        try? rep.tiffRepresentation?.write(to: file)
                        times.append(String(Int(elapsed * 1000)))
                        frame += 1
                    }
                    if elapsed >= scene.duration {
                        t.invalidate()
                        try? (times.joined(separator: "\n") + "\n").write(to: url.appendingPathComponent("times.txt"), atomically: true, encoding: .utf8)
                        print("Wrote \(frame) frames over \(String(format: "%.1f", elapsed)) s of scene time to \(folder)")
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
            // Fill the whole frame: the popover keeps its own height, which may be less than the frame.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            script.append((4.4, { m.submit() }))              // wrong → shake, right spelling, hint, copy drill
            script += typing("quintaval", into: m, at: 6.0)   // a copy with a mistake: red boxes, shake
            script.append((7.1, { m.submit() }))
            for (n, t) in [7.5, 8.8, 10.1].enumerated() {       // three right copies fill the dots
                script += typing("quintavel", into: m, at: t, every: 0.09)
                script.append((t + 0.95, { m.submit() }))
                _ = n
            }
            script += typing("zorbitude", into: m, at: 12.0)  // the next card came by itself
            script.append((13.2, { m.submit() }))
            return Scene(size: CGSize(width: HomeView.width + 48, height: 660), duration: 14.6,
                         view: AnyView(popover(QuizView(showsFooter: true).environmentObject(m).environmentObject(router))),
                         script: script)
        case "overview":
            let m = Harness.demoModelWithHistory(clock)
            m.settings.welcomeDone = true
            return Scene(size: CGSize(width: HomeView.width + 48, height: 900), duration: 3.4,
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
                            (0.7, { withAnimation(Motion.spring.scaled) { fix.phase = .asking(text) } }),
                            (2.2, { withAnimation(Motion.spring.scaled) { fix.phase = .done(text, Harness.sampleFix) } }),
                            (3.9, { fix.copied = "Fixed" }),
                         ])
        case "window", "practice":
            let m = Harness.demoModelWithHistory(clock)
            m.settings.welcomeDone = true
            let nav = Navigator()
            var script: [(Double, () -> Void)] = []
            if name == "window" {
                for (t, p) in [(1.6, Page.quiz), (3.4, Page.stats), (5.6, Page.fix), (7.0, Page.settings), (8.6, Page.overview)] {
                    script.append((t, { withAnimation(Motion.spring.scaled) { nav.page = p } }))
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
            return Scene(size: CGSize(width: 1000, height: 700), scale: 0.82, duration: name == "window" ? 10.4 : 5.6,
                         view: AnyView(view), script: script)
        default:
            return nil
        }
    }
}
