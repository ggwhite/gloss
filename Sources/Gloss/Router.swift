import AppKit

/// Actions the views can ask for. The app delegate fills them in; the screenshot leaves them empty.
final class Router: ObservableObject {
    var showStats: () -> Void = {}
    var showSettings: () -> Void = {}
    var showQuizWindow: () -> Void = {}
    var fixEnglish: () -> Void = {}
    var quit: () -> Void = { NSApp.terminate(nil) }
    var hotKeyLabel: () -> String = { HotKeyCombo.default.display }
    var openHotKeyLabel: () -> String = { HotKeyCombo.openDefault.display }
    var showOverview: () -> Void = {}
    var showAddWord: () -> Void = {}
}
