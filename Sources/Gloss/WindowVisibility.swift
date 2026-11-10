import AppKit
import SwiftUI

// Hidden windows keep their SwiftUI views alive: a closed main window or a dismissed menu popover is
// only ordered out. Continuous effects (the drifting wash, the floating logo) read this to stop while
// nobody can see them, so an idle Gloss uses no CPU.

private struct WindowVisibleKey: EnvironmentKey { static let defaultValue = true }

extension EnvironmentValues {
    /// True only while the window is on screen, not covered, and the one being used (key).
    /// False while it is closed, hidden, minimized, covered, or in the background behind another app.
    var windowVisible: Bool {
        get { self[WindowVisibleKey.self] }
        set { self[WindowVisibleKey.self] = newValue }
    }
}

/// Reports whether the window this view is in can be seen (its occlusion state).
private struct VisibilityReader: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ReaderView { ReaderView(onChange: onChange) }
    func updateNSView(_ v: ReaderView, context: Context) { v.onChange = onChange }

    final class ReaderView: NSView {
        var onChange: (Bool) -> Void
        private var observers: [NSObjectProtocol] = []
        /// Ordering a window out sends no notification, so its `isVisible` is watched too.
        private var visibleWatch: NSKeyValueObservation?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError("not used") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            visibleWatch = nil
            guard let window else { report(false); return }
            visibleWatch = window.observe(\.isVisible, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.report(nil) }
            }
            for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.willCloseNotification,
                         NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
                         NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] note in
                    MainActor.assumeIsolated {
                        self?.report(note.name == NSWindow.willCloseNotification ? false : nil)
                    }
                })
            }
            report(nil)
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }

        /// For measuring only (`--cpu-check` with GLOSS_ASSUME_IN_USE=1): any shown window counts as in use,
        /// so the cost of the effects while someone is looking can be measured without taking focus.
        static let assumeInUse = ProcessInfo.processInfo.environment["GLOSS_ASSUME_IN_USE"] != nil

        private func report(_ forced: Bool?) {
            let visible = forced ?? (window.map {
                Self.assumeInUse ? $0.isVisible
                    : $0.isVisible && $0.occlusionState.contains(.visible) && $0.isKeyWindow
            } ?? false)
            onChange(visible)
        }
    }
}

private struct TrackWindowVisibility: ViewModifier {
    @State private var visible = true

    func body(content: Content) -> some View {
        content
            .environment(\.windowVisible, visible)
            .background(VisibilityReader { v in if v != visible { visible = v } })
    }
}

extension View {
    /// Tells the views inside whether their window can be seen (see `windowVisible`).
    func trackWindowVisibility() -> some View { modifier(TrackWindowVisibility()) }
}
