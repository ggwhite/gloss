import AppKit
import SwiftUI

/// Puts the keyboard cursor into the text field it sits behind, through AppKit.
/// SwiftUI's @FocusState alone missed the first card of a freshly opened window or popover.
/// Bump `trigger` to ask again (each new card does). It never steals the cursor from a field
/// that is already being typed in, so letters are never lost or selected.
struct FocusAnchor: NSViewRepresentable {
    var trigger: Int

    func makeNSView(context: Context) -> AnchorView { AnchorView() }

    func updateNSView(_ v: AnchorView, context: Context) {
        if v.lastTrigger != trigger {
            v.lastTrigger = trigger
            v.focusSoon()
        }
    }

    final class AnchorView: NSView {
        var lastTrigger = Int.min
        private var keyObserver: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let keyObserver { NotificationCenter.default.removeObserver(keyObserver) }
            keyObserver = nil
            guard let window else { return }
            keyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.focusSoon() }
            }
            focusSoon()
        }

        deinit { if let keyObserver { NotificationCenter.default.removeObserver(keyObserver) } }

        /// Tries now and twice more, because a new field may not be in the window yet.
        func focusSoon() {
            for delay in [0.0, 0.12, 0.35] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.focusNow() }
            }
        }

        private func focusNow() {
            // Only the window being typed in: text fields share one editor, so a background window
            // (say the main window behind the menu popover) would otherwise pull the cursor away.
            guard let window, window.isKeyWindow, let root = window.contentView, !isHiddenOrHasHiddenAncestor else { return }
            guard let field = nearestField(in: root) else { return }
            if let editor = window.firstResponder as? NSTextView, editor.isFieldEditor,
               editor.delegate as? NSTextField === field {
                return // already typing in it
            }
            window.makeFirstResponder(field)
            // Put the caret at the end instead of selecting the text.
            if let editor = field.currentEditor() {
                editor.selectedRange = NSRange(location: (field.stringValue as NSString).length, length: 0)
            }
        }

        /// The editable text field whose frame is closest to this anchor's centre.
        private func nearestField(in root: NSView) -> NSTextField? {
            let mid = convert(NSPoint(x: bounds.midX, y: bounds.midY), to: root)
            var best: (NSTextField, CGFloat)?
            func walk(_ v: NSView) {
                if let tf = v as? NSTextField, tf.isEditable, !tf.isHiddenOrHasHiddenAncestor {
                    let f = tf.convert(tf.bounds, to: root)
                    let d = hypot(f.midX - mid.x, f.midY - mid.y)
                    if best == nil || d < best!.1 { best = (tf, d) }
                }
                for s in v.subviews { walk(s) }
            }
            walk(root)
            return best?.0
        }
    }
}
