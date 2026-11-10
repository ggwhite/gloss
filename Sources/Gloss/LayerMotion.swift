import AppKit
import QuartzCore
import SwiftUI

// Continuous decoration run by Core Animation in the window server, so Gloss itself spends no CPU on it
// (SwiftUI timelines re-ran the view graph 10–20 times a second). Paused while the window isn't in use.

/// The violet wash with three glows drifting on slow loops (24 s, 30 s, 36 s).
struct LayerWash: NSViewRepresentable {
    var running: Bool

    func makeNSView(context: Context) -> WashView { WashView() }
    func updateNSView(_ v: WashView, context: Context) { v.setRunning(running) }

    final class WashView: NSView {
        private let base = CAGradientLayer()
        private var glows: [CAGradientLayer] = []

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            let root = CALayer()
            layer = root
            base.colors = [NSColor(srgbRed: 0.07, green: 0.06, blue: 0.24, alpha: 0.86).cgColor,
                           NSColor(srgbRed: 0.26, green: 0.10, blue: 0.55, alpha: 0.80).cgColor]
            base.startPoint = CGPoint(x: 0, y: 1)
            base.endPoint = CGPoint(x: 1, y: 0)
            root.addSublayer(base)
            let specs: [(NSColor, CGFloat, Double)] = [
                (NSColor(srgbRed: 0.55, green: 0.25, blue: 0.95, alpha: 0.45), 440, 24),
                (NSColor(srgbRed: 0.20, green: 0.35, blue: 0.95, alpha: 0.28), 340, 30),
                (NSColor(srgbRed: 0.30, green: 0.85, blue: 0.85, alpha: 0.10), 300, 36),
            ]
            for (color, radius, _) in specs {
                let g = CAGradientLayer()
                g.type = .radial
                g.colors = [color.cgColor, color.withAlphaComponent(0).cgColor]
                g.startPoint = CGPoint(x: 0.5, y: 0.5)
                g.endPoint = CGPoint(x: 1, y: 1)
                g.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
                root.addSublayer(g)
                glows.append(g)
            }
            durations = specs.map(\.2)
        }
        required init?(coder: NSCoder) { fatalError("not used") }

        private var durations: [Double] = []
        private var running = false

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            base.frame = bounds
            // Centres (as a share of the view, origin bottom-left) and drift sizes, like the SwiftUI wash.
            let centres: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(0.85, 0.10, 0.12, 0.08), (0.12, 0.90, 0.10, 0.08), (0.5, 0.55, 0.3, 0.2)]
            for (i, g) in glows.enumerated() {
                let c = centres[i]
                let centre = CGPoint(x: bounds.width * c.0, y: bounds.height * c.1)
                g.position = centre
                g.removeAnimation(forKey: "drift")
                let path = CGPath(ellipseIn: CGRect(x: centre.x - bounds.width * c.2, y: centre.y - bounds.height * c.3,
                                                    width: bounds.width * c.2 * 2, height: bounds.height * c.3 * 2),
                                  transform: nil)
                let a = CAKeyframeAnimation(keyPath: "position")
                a.path = path
                a.duration = durations[i]
                a.repeatCount = .infinity
                a.calculationMode = .paced
                g.add(a, forKey: "drift")
            }
            CATransaction.commit()
            applySpeed()
        }

        func setRunning(_ on: Bool) {
            running = on
            applySpeed()
        }

        /// Pausing keeps the glows where they are (speed 0), so nothing is drawn while hidden.
        private func applySpeed() {
            guard let root = layer else { return }
            if running, root.speed == 0 {
                let paused = root.timeOffset
                root.speed = 1
                root.timeOffset = 0
                root.beginTime = 0
                root.beginTime = root.convertTime(CACurrentMediaTime(), from: nil) - paused
            } else if !running, root.speed != 0 {
                let now = root.convertTime(CACurrentMediaTime(), from: nil)
                root.speed = 0
                root.timeOffset = now
            }
        }
    }
}

/// The app icon bobbing gently up and down (4.8 s loop), drawn once as an image.
struct FloatingAppIcon: View {
    var size: CGFloat
    @Environment(\.windowVisible) private var visible
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        LayerBob(image: AppIconView.image(size: size), running: visible && !reduce)
            .frame(width: size, height: size)
    }
}

private struct LayerBob: NSViewRepresentable {
    var image: NSImage
    var running: Bool

    func makeNSView(context: Context) -> BobView { BobView(image: image) }
    func updateNSView(_ v: BobView, context: Context) { v.setRunning(running) }

    final class BobView: NSView {
        private let content = CALayer()

        init(image: NSImage) {
            super.init(frame: .zero)
            wantsLayer = true
            layer = CALayer()
            layer?.masksToBounds = false
            content.contents = image
            content.contentsGravity = .resizeAspect
            layer?.addSublayer(content)
        }
        required init?(coder: NSCoder) { fatalError("not used") }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            content.frame = bounds
            content.contentsScale = window?.backingScaleFactor ?? 2
            CATransaction.commit()
        }

        func setRunning(_ on: Bool) {
            if on {
                guard content.animation(forKey: "bob") == nil else { return }
                let a = CABasicAnimation(keyPath: "transform.translation.y")
                a.fromValue = -3
                a.toValue = 3
                a.duration = 2.4
                a.autoreverses = true
                a.repeatCount = .infinity
                a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                content.add(a, forKey: "bob")
            } else {
                content.removeAnimation(forKey: "bob")
            }
        }
    }
}
