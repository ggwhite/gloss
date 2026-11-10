import AppKit
import SwiftUI

/// Shapes the menu bar popover window (MenuBarExtra), which SwiftUI leaves as a clear, borderless,
/// unclipped window that keeps the size it opened with:
/// - clips it to `Theme.popoverRadius` rounded corners and makes the shadow follow that shape;
/// - resizes it to the content whenever the content's height changes (overview ↔ quiz), keeping its
///   top edge under the menu bar. Without this the quiz floated in the middle of the taller overview
///   window, with an empty gap above it.
/// Other windows that use the same look (screenshots, recordings) are left alone.
struct PopoverWindowShaper: NSViewRepresentable {
    var contentHeight: CGFloat

    func makeNSView(context: Context) -> ShaperView { ShaperView() }
    func updateNSView(_ nsView: ShaperView, context: Context) {
        nsView.contentHeight = contentHeight
        nsView.apply()
    }

    final class ShaperView: NSView {
        var contentHeight: CGFloat = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        private var isMenuBarPopover: Bool {
            guard let window else { return false }
            return String(describing: type(of: window)).contains("MenuBarExtra")
        }

        func apply() {
            guard let window, isMenuBarPopover, let frameView = window.contentView?.superview else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            frameView.wantsLayer = true
            if let layer = frameView.layer {
                layer.cornerRadius = Theme.popoverRadius
                layer.cornerCurve = .continuous
                layer.masksToBounds = true
            }
            fitHeight()
            window.invalidateShadow()
        }

        /// Makes the window exactly as tall as the content, keeping its top edge where it is.
        private func fitHeight() {
            guard let window, contentHeight > 1 else { return }
            var f = window.frame
            guard abs(f.height - contentHeight) > 0.5 else { return }
            let top = f.maxY
            f.size.height = contentHeight
            f.origin.y = top - contentHeight
            window.setFrame(f, display: true, animate: false)
        }
    }
}

private struct PopoverHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Measures the content, then hands its height to the window shaper.
private struct PopoverChrome: ViewModifier {
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.popoverRadius, style: .continuous)
        content
            .background(GeometryReader { g in Color.clear.preference(key: PopoverHeightKey.self, value: g.size.height) })
            .onPreferenceChange(PopoverHeightKey.self) { h in
                if abs(h - height) > 0.5 { height = h }
            }
            .background(AnimatedWash().clipShape(shape))
            .clipShape(shape)
            .overlay(shape.stroke(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .background(PopoverWindowShaper(contentHeight: height))
    }
}

extension View {
    /// The popover's look: violet wash and a light edge with rounded corners; in the menu bar popover
    /// the window also follows the content's height.
    func popoverChrome() -> some View { modifier(PopoverChrome()) }
}
