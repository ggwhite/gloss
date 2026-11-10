import AppKit

/// `--inspect-popover <file.txt>`: opens the menu bar popover invisibly (alpha 0), writes its window
/// and view structure plus a PNG beside the file, then quits. Used to fix the popover's shape.
@MainActor
enum PopoverInspector {
    static var outputPath: String?

    static func start() {
        guard let path = outputPath else { return }
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didUpdateNotification, object: nil, queue: nil) { note in
            MainActor.assumeIsolated {
                guard let w = note.object as? NSWindow, !String(describing: type(of: w)).contains("StatusBar") else { return }
                w.alphaValue = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let button = statusButton() else { write("no status button", to: path); exit(1) }
            button.performClick(nil)
            var measured = ""
            let pop = { NSApp.windows.first(where: { String(describing: type(of: $0)).contains("MenuBarExtra") }) }
            let note = { (label: String) in
                if let w = pop() { measured += "\(label) frame=\(w.frame) top=\(w.frame.maxY)\n" }
            }
            let switching = CommandLine.arguments.contains("--switch-quiz")
            if switching {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { note("OVERVIEW"); AppDelegate.current?.model.showingQuiz = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { note("QUIZ    "); AppDelegate.current?.model.showingQuiz = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { note("BACK    ") }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (switching ? 3.6 : 1.0)) {
                var out = measured
                for w in NSApp.windows where w.isVisible {
                    out += "WINDOW \(type(of: w)) frame=\(w.frame) opaque=\(w.isOpaque) bg=\(String(describing: w.backgroundColor)) style=\(w.styleMask.rawValue) shadow=\(w.hasShadow) level=\(w.level.rawValue)\n"
                    if let frameView = w.contentView?.superview { dump(frameView, depth: 1, into: &out) }
                    if !String(describing: type(of: w)).contains("StatusBar"), let cv = w.contentView {
                        w.alphaValue = 1
                        if let rep = cv.bitmapImageRepForCachingDisplay(in: cv.bounds) {
                            cv.cacheDisplay(in: cv.bounds, to: rep)
                            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path + ".png"))
                        }
                        w.alphaValue = 0
                    }
                }
                if let observer { NotificationCenter.default.removeObserver(observer) }
                write(out, to: path)
                exit(0)
            }
        }
    }

    private static func statusButton() -> NSStatusBarButton? {
        for w in NSApp.windows where String(describing: type(of: w)).contains("StatusBar") {
            if let b = find(NSStatusBarButton.self, in: w.contentView) { return b }
        }
        return nil
    }

    private static func find<T: NSView>(_ t: T.Type, in v: NSView?) -> T? {
        guard let v else { return nil }
        if let hit = v as? T { return hit }
        for s in v.subviews { if let hit = find(t, in: s) { return hit } }
        return nil
    }

    private static func dump(_ v: NSView, depth: Int, into out: inout String) {
        guard depth < 7 else { return }
        let layer = v.layer.map { " layer.corner=\($0.cornerRadius) masks=\($0.masksToBounds)" } ?? ""
        out += String(repeating: "  ", count: depth) + "\(type(of: v)) frame=\(v.frame) hidden=\(v.isHidden)\(layer)\n"
        for s in v.subviews { dump(s, depth: depth + 1, into: &out) }
    }

    private static func write(_ s: String, to path: String) {
        try? s.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
