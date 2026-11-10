import SwiftUI

// Shared motion. Every effect checks Reduce Motion (System Settings → Accessibility → Display).
// Timings are in MECHANICS.md ("Motion").

enum Motion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.72)
    /// Delay between tiles that fade in one after another.
    static let stagger: Double = 0.06
}

/// Fades and slides a view in when it appears, after `delay` seconds.
struct AppearIn: ViewModifier {
    var delay: Double = 0
    var offset: CGFloat = 14
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduce ? 1 : 0)
            .offset(y: shown || reduce ? 0 : offset)
            .scaleEffect(shown || reduce ? 1 : 0.97, anchor: .top)
            .onAppear {
                guard !reduce else { return }
                withAnimation(Motion.spring.delay(delay)) { shown = true }
            }
    }
}

/// Shakes sideways once each time `trigger` changes (a wrong answer).
struct Shake: GeometryEffect {
    var amount: CGFloat = 9
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes * 2), y: 0))
    }
}

/// Lifts a card a little under the mouse pointer.
struct HoverLift: ViewModifier {
    var radius: CGFloat = 18
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering && !reduce ? 1.015 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(hovering ? 0.22 : 0), lineWidth: 1)
            )
            .shadow(color: Theme.accent.opacity(hovering ? 0.35 : 0), radius: hovering ? 16 : 0, y: hovering ? 6 : 0)
            .onHover { h in withAnimation(Motion.snappy) { hovering = h } }
    }
}

/// A burst of small sparks around the card for a right answer.
struct SparkBurst: View {
    var colors: [Color] = [Theme.good, Theme.link, Theme.violet, Theme.warn]
    @State private var fly = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    private let count = 16

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let angle = Double(i) / Double(count) * 2 * .pi + 0.2
                let distance: CGFloat = i.isMultiple(of: 2) ? 120 : 84
                Group {
                    if i.isMultiple(of: 3) {
                        Image(systemName: "sparkle").font(.system(size: 13, weight: .bold))
                    } else {
                        Circle().frame(width: 7, height: 7)
                    }
                }
                .foregroundStyle(colors[i % colors.count])
                .offset(x: fly ? cos(angle) * distance : 0, y: fly ? sin(angle) * distance * 0.6 : 0)
                .scaleEffect(fly ? 0.4 : 1.1)
                .opacity(fly ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduce else { fly = true; return }
            withAnimation(.easeOut(duration: 0.85)) { fly = true }
        }
    }
}

/// A number that rolls up from 0 when it first appears, and rolls between values after that.
struct RollingNumber: View {
    var value: Int
    var font: Font
    var color: Color = .primary
    var delay: Double = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        Text("\(shown || reduce ? value : 0)")
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(shown ? value : 0)))
            .animation(Motion.spring, value: value)
            .onAppear {
                guard !reduce else { return }
                withAnimation(.easeOut(duration: 0.8).delay(delay)) { shown = true }
            }
    }
}

/// The violet wash, with its glows drifting slowly (about one loop every 24 s).
/// It redraws 12 times a second, and not at all while its window can't be seen.
struct AnimatedWash: View {
    /// Redraws per second while visible. See MECHANICS.md ("Motion").
    static let fps: Double = 12

    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.windowVisible) private var visible

    var body: some View {
        if reduce {
            Theme.wash
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / Self.fps, paused: !visible)) { context in
                let t = context.date.timeIntervalSinceReferenceDate / 24 * 2 * .pi
                ZStack {
                    LinearGradient(colors: [Color(red: 0.07, green: 0.06, blue: 0.24).opacity(0.86),
                                            Color(red: 0.26, green: 0.10, blue: 0.55).opacity(0.80)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    RadialGradient(colors: [Color(red: 0.55, green: 0.25, blue: 0.95).opacity(0.45), .clear],
                                   center: UnitPoint(x: 0.85 + 0.12 * cos(t), y: 0.9 + 0.08 * sin(t)),
                                   startRadius: 0, endRadius: 440)
                    RadialGradient(colors: [Color(red: 0.20, green: 0.35, blue: 0.95).opacity(0.28), .clear],
                                   center: UnitPoint(x: 0.12 + 0.10 * sin(t * 0.8), y: 0.10 + 0.08 * cos(t * 0.8)),
                                   startRadius: 0, endRadius: 340)
                    RadialGradient(colors: [Color(red: 0.30, green: 0.85, blue: 0.85).opacity(0.10), .clear],
                                   center: UnitPoint(x: 0.5 + 0.3 * sin(t * 0.6), y: 0.45 + 0.2 * cos(t * 0.5)),
                                   startRadius: 0, endRadius: 300)
                }
            }
        }
    }
}

/// Bobs a view up and down gently (the logo), only while its window can be seen.
struct FloatingBob: ViewModifier {
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.windowVisible) private var visible

    func body(content: Content) -> some View {
        content
            .offset(y: up && !reduce ? -3 : 3)
            .onAppear { setRunning(visible) }
            .onChange(of: visible) { _, v in setRunning(v) }
    }

    private func setRunning(_ on: Bool) {
        if on && !reduce {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { up = true }
        } else {
            // A plain change replaces the endless animation, so nothing keeps redrawing.
            var t = Transaction(animation: nil)
            t.disablesAnimations = true
            withTransaction(t) { up = false }
        }
    }
}

extension View {
    func appearIn(delay: Double = 0, offset: CGFloat = 14) -> some View { modifier(AppearIn(delay: delay, offset: offset)) }
    func hoverLift(radius: CGFloat = 18) -> some View { modifier(HoverLift(radius: radius)) }
    func floating() -> some View { modifier(FloatingBob()) }
}
