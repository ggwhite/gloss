import AppKit
import SwiftUI

// One glass look for every screen:
// - macOS 26+: Apple's Liquid Glass (`glassEffect`).
// - macOS 14–15: a frosted material with a light edge.
// - Screenshot mode: a drawn copy of the glass, because an offscreen snapshot cannot capture
//   the blur of what is behind a window.

private struct SimulatedGlassKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// True in `--screenshot` mode: glass is drawn by hand instead of by the window server.
    var simulatedGlass: Bool {
        get { self[SimulatedGlassKey.self] }
        set { self[SimulatedGlassKey.self] = newValue }
    }
}

struct GlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color?
    /// 0…1. Low values only colour the glass; high values make a solid coloured button.
    var tintStrength: Double = 0.2
    var interactive = false
    @Environment(\.simulatedGlass) private var simulated
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        if simulated {
            content.background(DrawnGlass(shape: shape, tint: tint, tintStrength: tintStrength, dark: scheme == .dark))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .background(shape.fill((tint ?? .clear).opacity(tintStrength)))
                .overlay(shape.stroke(Edge.gradient(dark: scheme == .dark), lineWidth: 0.8))
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint.opacity(min(1, tintStrength * 1.6))) }
        if interactive { g = g.interactive() }
        return g
    }
}

private enum Edge {
    /// The bright top edge and dim bottom edge that make glass read as glass.
    static func gradient(dark: Bool) -> LinearGradient {
        LinearGradient(colors: [Color.white.opacity(dark ? 0.35 : 0.9), Color.white.opacity(dark ? 0.05 : 0.25)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// A hand-drawn glass surface for screenshots: milky fill, tint, top sheen, bright edge, soft shadow.
struct DrawnGlass<S: Shape>: View {
    let shape: S
    var tint: Color?
    var tintStrength: Double
    var dark = false

    var body: some View {
        ZStack {
            shape.fill(Color.white.opacity(dark ? 0.07 : 0.42))
            if let tint { shape.fill(tint.opacity(tintStrength)) }
            shape.fill(LinearGradient(colors: [Color.white.opacity(dark ? 0.16 : 0.55), Color.white.opacity(0.0)],
                                      startPoint: .top, endPoint: .center))
                .blendMode(.screen)
            shape.stroke(Edge.gradient(dark: dark), lineWidth: 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(dark ? 0.35 : 0.10), radius: 16, y: 8)
    }
}

extension View {
    func glass<S: Shape>(_ shape: S, tint: Color? = nil, strength: Double = 0.2, interactive: Bool = false) -> some View {
        modifier(GlassModifier(shape: shape, tint: tint, tintStrength: strength, interactive: interactive))
    }

    /// A rounded glass card.
    func glassCard(radius: CGFloat = 20, tint: Color? = nil, strength: Double = 0.15) -> some View {
        glass(RoundedRectangle(cornerRadius: radius, style: .continuous), tint: tint, strength: strength)
    }

    /// Groups glass shapes so they blend into each other on macOS 26.
    @ViewBuilder func glassGroup(spacing: CGFloat = 10) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

/// A capsule glass button. `prominent` fills it with colour, for the main action.
struct GlassPillStyle: ButtonStyle {
    var tint: Color? = nil
    var prominent = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, tint: tint, prominent: prominent, compact: compact)
    }

    private struct PillBody: View {
        let configuration: Configuration
        var tint: Color?
        var prominent: Bool
        var compact: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(compact ? .caption.weight(.medium) : .callout.weight(.semibold))
                .padding(.horizontal, compact ? 10 : 14)
                .padding(.vertical, compact ? 5 : 7)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .glass(Capsule(), tint: prominent ? (tint ?? Theme.accent) : tint,
                       strength: prominent ? 0.85 : (hovering ? 0.22 : 0.12), interactive: true)
                .overlay(Capsule().fill(Color.white.opacity(hovering ? 0.08 : 0)))
                .contentShape(Capsule())
                .brightness(hovering ? 0.06 : 0)
                .scaleEffect(configuration.isPressed ? 0.94 : (hovering ? 1.03 : 1))
                .animation(Motion.snappy, value: configuration.isPressed)
                .animation(Motion.snappy, value: hovering)
                .onHover { hovering = $0 }
        }
    }
}

/// A round glass icon button.
struct GlassCircleStyle: ButtonStyle {
    var size: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        CircleBody(configuration: configuration, size: size)
    }

    private struct CircleBody: View {
        let configuration: Configuration
        var size: CGFloat
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(hovering ? Color.white : Color.primary)
                .glass(Circle(), tint: hovering ? Theme.accent : nil, strength: hovering ? 0.35 : 0.1, interactive: true)
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed ? 0.9 : (hovering ? 1.08 : 1))
                .animation(Motion.snappy, value: configuration.isPressed)
                .animation(Motion.snappy, value: hovering)
                .onHover { hovering = $0 }
        }
    }
}

/// A frosted window background (the desktop shows through, blurred).
struct WindowGlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}

/// A dark blue-violet colour wash behind the glass, so the glass has something to refract.
struct AuroraBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.navy, Theme.plum], startPoint: .topLeading, endPoint: .bottomTrailing)
            blob(Theme.blue.opacity(0.55), at: .init(x: 0.10, y: 0.10), radius: 460)
            blob(Theme.violet.opacity(0.55), at: .init(x: 0.88, y: 0.90), radius: 480)
            blob(Theme.accent.opacity(0.45), at: .init(x: 0.50, y: 1.05), radius: 380)
        }
    }

    private func blob(_ c: Color, at p: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(colors: [c, c.opacity(0)], center: p, startRadius: 0, endRadius: radius)
    }
}
