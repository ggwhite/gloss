import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Copies the selected text of the front app: saves the pasteboard, sends ⌘C, reads it, puts the old contents back.
enum SelectionGrabber {
    enum Failure: Error, LocalizedError {
        case noPermission
        case nothingSelected

        var errorDescription: String? {
            switch self {
            case .noPermission: return "Gloss needs Accessibility permission to copy your selection."
            case .nothingSelected: return "No text is selected. Select some English text, then press the shortcut again."
            }
        }
    }

    /// How long to wait for the front app to answer ⌘C. See MECHANICS.md.
    static let copyTimeout: TimeInterval = 0.6

    static func copySelection() async throws -> String {
        guard AXIsProcessTrusted() else { throw Failure.noPermission }
        let pb = NSPasteboard.general
        let saved = snapshot(pb)
        let before = pb.changeCount

        // Wait until the shortcut's modifier keys are up, so the app sees a plain ⌘C.
        for _ in 0..<20 where !NSEvent.modifierFlags.intersection([.control, .option, .shift]).isEmpty {
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        sendCommandC()

        let deadline = Date().addingTimeInterval(copyTimeout)
        while pb.changeCount == before && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        let text = pb.changeCount == before ? nil : pb.string(forType: .string)
        restore(saved, to: pb)
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure.nothingSelected
        }
        return text
    }

    private static func sendCommandC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_C)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private typealias Saved = [[(NSPasteboard.PasteboardType, Data)]]

    private static func snapshot(_ pb: NSPasteboard) -> Saved {
        (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { t in item.data(forType: t).map { (t, $0) } }
        }
    }

    private static func restore(_ saved: Saved, to pb: NSPasteboard) {
        pb.clearContents()
        guard !saved.isEmpty else { return }
        let items: [NSPasteboardItem] = saved.map { pairs in
            let item = NSPasteboardItem()
            for (t, d) in pairs { item.setData(d, forType: t) }
            return item
        }
        pb.writeObjects(items)
    }
}
