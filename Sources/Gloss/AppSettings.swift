import Foundation
import GlossCore

/// User settings, saved in UserDefaults.
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var vaultPath: String { didSet { defaults.set(vaultPath, forKey: Keys.vaultPath) } }
    @Published var spellingDeck: Bool { didSet { defaults.set(spellingDeck, forKey: Keys.spellingDeck) } }
    @Published var usageDeck: Bool { didSet { defaults.set(usageDeck, forKey: Keys.usageDeck) } }
    /// New words: `## 問過的字` and words added in Gloss.
    @Published var askedDeck: Bool { didSet { defaults.set(askedDeck, forKey: Keys.askedDeck) } }
    /// Claude model for Fix My English and word look-ups: "haiku" (fastest) or "sonnet".
    @Published var claudeModel: String { didSet { defaults.set(claudeModel, forKey: Keys.claudeModel) } }
    /// Keep one Claude started and waiting, so answers come in about 2 s.
    @Published var keepClaudeReady: Bool { didSet { defaults.set(keepClaudeReady, forKey: Keys.keepClaudeReady) } }
    @Published var nudgeMinutes: Int { didSet { defaults.set(nudgeMinutes, forKey: Keys.nudgeMinutes) } }
    @Published var nudgesOn: Bool { didSet { defaults.set(nudgesOn, forKey: Keys.nudgesOn) } }
    @Published var quietStart: Int { didSet { defaults.set(quietStart, forKey: Keys.quietStart) } }
    @Published var quietEnd: Int { didSet { defaults.set(quietEnd, forKey: Keys.quietEnd) } }
    @Published var newPerDay: Int { didSet { defaults.set(newPerDay, forKey: Keys.newPerDay) } }
    @Published var speakOnAnswer: Bool { didSet { defaults.set(speakOnAnswer, forKey: Keys.speakOnAnswer) } }
    @Published var speakOnShow: Bool { didSet { defaults.set(speakOnShow, forKey: Keys.speakOnShow) } }
    /// The voice id chosen in Settings; empty means "the most natural one installed".
    @Published var speakVoice: String {
        didSet { defaults.set(speakVoice, forKey: Keys.speakVoice); Pronouncer.chosenVoice = speakVoice }
    }
    @Published var hotKey: HotKeyCombo {
        didSet { defaults.set(try? JSONEncoder().encode(hotKey), forKey: Keys.hotKey) }
    }
    @Published var openHotKey: HotKeyCombo {
        didSet { defaults.set(try? JSONEncoder().encode(openHotKey), forKey: Keys.openHotKey) }
    }
    @Published var welcomeDone: Bool { didSet { defaults.set(welcomeDone, forKey: Keys.welcomeDone) } }
    /// While the Gloss window is open, show Gloss in the Dock and in ⌘Tab.
    @Published var dockWhileOpen: Bool { didSet { defaults.set(dockWhileOpen, forKey: Keys.dockWhileOpen) } }
    /// After a wrong answer, type the right spelling this many times (0 turns it off).
    @Published var copyReps: Int { didSet { defaults.set(copyReps, forKey: Keys.copyReps) } }
    /// Append Fix My English mistakes to 錯誤紀錄 and update 單字.md. Off by default.
    @Published var saveFixMistakes: Bool { didSet { defaults.set(saveFixMistakes, forKey: Keys.saveFixMistakes) } }

    enum Keys {
        static let vaultPath = "vaultPath", spellingDeck = "deck.spelling", usageDeck = "deck.usage"
        static let nudgeMinutes = "nudge.minutes", nudgesOn = "nudge.on"
        static let quietStart = "quiet.start", quietEnd = "quiet.end"
        static let newPerDay = "newPerDay", hotKey = "hotKey", lastNudge = "nudge.last"
        static let speakOnAnswer = "speak.onAnswer", speakOnShow = "speak.onShow", speakVoice = "speak.voice"
        static let openHotKey = "openHotKey", welcomeDone = "welcomeDone", dockWhileOpen = "dockWhileOpen"
        static let copyReps = "copyReps"
        static let saveFixMistakes = "fix.saveToVault"
        static let askedDeck = "deck.asked", claudeModel = "claude.model", keepClaudeReady = "claude.keepReady"
    }

    /// Defaults; see MECHANICS.md.
    enum Defaults {
        static let nudgeMinutes = 60
        static let newPerDay = 10
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        vaultPath = defaults.string(forKey: Keys.vaultPath) ?? Vault.defaultPath
        spellingDeck = defaults.object(forKey: Keys.spellingDeck) as? Bool ?? true
        usageDeck = defaults.object(forKey: Keys.usageDeck) as? Bool ?? false
        askedDeck = defaults.object(forKey: Keys.askedDeck) as? Bool ?? true
        claudeModel = defaults.string(forKey: Keys.claudeModel) ?? "haiku"
        keepClaudeReady = defaults.object(forKey: Keys.keepClaudeReady) as? Bool ?? true
        nudgeMinutes = defaults.object(forKey: Keys.nudgeMinutes) as? Int ?? Defaults.nudgeMinutes
        nudgesOn = defaults.object(forKey: Keys.nudgesOn) as? Bool ?? true
        quietStart = defaults.object(forKey: Keys.quietStart) as? Int ?? QuietHours.default.start
        quietEnd = defaults.object(forKey: Keys.quietEnd) as? Int ?? QuietHours.default.end
        newPerDay = defaults.object(forKey: Keys.newPerDay) as? Int ?? Defaults.newPerDay
        let voice = defaults.string(forKey: Keys.speakVoice) ?? ""
        speakVoice = voice
        Pronouncer.chosenVoice = voice
        speakOnAnswer = defaults.object(forKey: Keys.speakOnAnswer) as? Bool ?? true
        speakOnShow = defaults.object(forKey: Keys.speakOnShow) as? Bool ?? false
        if let data = defaults.data(forKey: Keys.hotKey), let k = try? JSONDecoder().decode(HotKeyCombo.self, from: data) {
            hotKey = k
        } else {
            hotKey = .default
        }
        if let data = defaults.data(forKey: Keys.openHotKey), let k = try? JSONDecoder().decode(HotKeyCombo.self, from: data) {
            openHotKey = k
        } else {
            openHotKey = .openDefault
        }
        welcomeDone = defaults.bool(forKey: Keys.welcomeDone)
        dockWhileOpen = defaults.object(forKey: Keys.dockWhileOpen) as? Bool ?? true
        copyReps = defaults.object(forKey: Keys.copyReps) as? Int ?? CopyDrill.defaultReps
        saveFixMistakes = defaults.object(forKey: Keys.saveFixMistakes) as? Bool ?? false
    }

    var decks: Set<Deck> {
        var s: Set<Deck> = []
        if spellingDeck { s.insert(.spelling) }
        if usageDeck { s.insert(.usage) }
        if askedDeck { s.insert(.asked) }
        return s
    }

    var quietHours: QuietHours { QuietHours(start: quietStart, end: quietEnd) }

    var lastNudge: Date? {
        get { defaults.object(forKey: Keys.lastNudge) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastNudge) }
    }
}
