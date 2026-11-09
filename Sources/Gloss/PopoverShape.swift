import AppKit
import SwiftUI

/// Rounds the menu bar popover window itself. The MenuBarExtra window is a clear, borderless window
/// whose frame view does not clip (corner radius 0), so a full-size background drew square corners.
/// This clips the whole window to `Theme.popoverRadius` and makes its shadow follow the rounded shape.
struct PopoverWindowShaper: NSViewRepresentable {
    func makeNSView(context: Context) -> ShaperView { ShaperView() }
    func updateNSView(_ nsView: ShaperView, context: Context) { nsView.apply() }

    final class ShaperView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func apply() {
            guard let window, let frameView = window.contentView?.superview else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            frameView.wantsLayer = true
            if let layer = frameView.layer {
                layer.cornerRadius = Theme.popoverRadius
                layer.cornerCurve = .continuous
                layer.masksToBounds = true
            }
            window.invalidateShadow()
        }
    }
}

extension View {
    /// The popover's look: violet wash and a light edge, both with the window's rounded corners.
    func popoverChrome() -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.popoverRadius, style: .continuous)
        return self
            .background(AnimatedWash().clipShape(shape))
            .clipShape(shape)
            .overlay(shape.stroke(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .background(PopoverWindowShaper())
    }
}
