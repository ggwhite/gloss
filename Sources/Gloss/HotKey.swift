import AppKit
import Carbon.HIToolbox

/// A global shortcut: a virtual key code plus Carbon modifier flags.
struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    /// The key's label, e.g. "E".
    var key: String

    /// ⌃⌥E: fix my English.
    static let `default` = HotKeyCombo(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(controlKey | optionKey), key: "E")
    /// ⌃⌥G: open the Gloss overview.
    static let openDefault = HotKeyCombo(keyCode: UInt32(kVK_ANSI_G), modifiers: UInt32(controlKey | optionKey), key: "G")

    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + key
    }

    /// Builds a combo from a key press; nil when no modifier (other than Shift) is held.
    init?(event: NSEvent) {
        let f = event.modifierFlags
        var m: UInt32 = 0
        if f.contains(.control) { m |= UInt32(controlKey) }
        if f.contains(.option) { m |= UInt32(optionKey) }
        if f.contains(.shift) { m |= UInt32(shiftKey) }
        if f.contains(.command) { m |= UInt32(cmdKey) }
        guard m & ~UInt32(shiftKey) != 0 else { return nil }
        keyCode = UInt32(event.keyCode)
        modifiers = m
        key = (event.charactersIgnoringModifiers ?? "?").uppercased()
        if key.isEmpty || key == " " { key = event.keyCode == UInt16(kVK_Space) ? "Space" : "#\(event.keyCode)" }
    }

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }
}

/// Registers global hotkeys with Carbon (no Accessibility permission needed for this part).
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    enum Slot: UInt32 {
        case fixEnglish = 1
        case openMenu = 2
    }

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false

    func register(_ slot: Slot, _ combo: HotKeyCombo, handler: @escaping () -> Void) {
        installHandler()
        if let old = refs[slot.rawValue] { UnregisterEventHotKey(old) }
        refs[slot.rawValue] = nil
        handlers[slot.rawValue] = handler
        let id = EventHotKeyID(signature: OSType(0x474C5353), id: slot.rawValue) // 'GLSS'
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &newRef)
        if status == noErr { refs[slot.rawValue] = newRef } else { NSLog("Gloss: hotkey \(slot) register failed \(status)") }
    }

    fileprivate func fire(_ id: UInt32) { handlers[id]?() }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hk = EventHotKeyID()
            let err = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            guard err == noErr else { return err }
            let id = hk.id
            DispatchQueue.main.async { HotKeyCenter.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
