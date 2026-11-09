import Combine
import Foundation
import GlossCore

/// The app's state: the vault, the saved progress and the running quiz.
@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case asking
        case correct(VocabEntry)
        case wrong(AnswerOutcome)
        case done
    }

    @Published private(set) var snapshot = VaultSnapshot()
    @Published private(set) var state: GlossState
    @Published private(set) var dueCount = 0
    @Published private(set) var current: VocabEntry?
    @Published var phase: Phase = .asking
    @Published var answer = ""
    @Published private(set) var sessionRemaining = 0
    @Published private(set) var sessionAnswered = 0
    @Published private(set) var sessionCorrect = 0
    @Published private(set) var lastSaveError: String?

    let settings: AppSettings
    let now: () -> Date
    var calendar: Calendar
    /// nil keeps progress in memory only (screenshot and self-test).
    private let store: StateStore?
    /// Fixed vault content (demo); nil reads the vault folder from settings.
    private let fixedSnapshot: VaultSnapshot?
    private var session: QuizSession?
    private var fingerprint = ""
    private var bag: Set<AnyCancellable> = []

    /// How long the green check stays before the next card (seconds). See MECHANICS.md.
    static let correctPause: Double = 0.7

    init(settings: AppSettings, store: StateStore?, fixedSnapshot: VaultSnapshot? = nil,
         calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.store = store
        self.fixedSnapshot = fixedSnapshot
        self.calendar = calendar
        self.now = now
        state = store?.load() ?? GlossState()
        reloadVault(force: true)

        settings.objectWillChange
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.settingsChanged() }
            .store(in: &bag)
    }

    var scheduler: LeitnerScheduler { LeitnerScheduler(calendar: calendar) }
    var today: Day { Day(now(), calendar: calendar) }
    var entries: [VocabEntry] { snapshot.entries(for: settings.decks) }
    var resolvedVaultPath: String { Vault.resolve(settings.vaultPath).path }

    // MARK: Vault

    /// Reads the vault again when its files changed (or always with `force`).
    func reloadVault(force: Bool = false) {
        if let fixedSnapshot {
            snapshot = fixedSnapshot
        } else {
            let fp = Vault.fingerprint(path: settings.vaultPath)
            guard force || fp != fingerprint else { return }
            fingerprint = fp
            snapshot = Vault.load(path: settings.vaultPath, now: now())
        }
        refreshDue()
        if session == nil || phase == .done { startSession() }
    }

    private var lastDecks: Set<Deck> = []
    private var lastPath = ""
    private func settingsChanged() {
        if settings.decks != lastDecks || settings.vaultPath != lastPath {
            lastDecks = settings.decks
            lastPath = settings.vaultPath
            reloadVault(force: true)
            startSession()
        } else {
            refreshDue()
        }
    }

    // MARK: Due cards

    func dueCards() -> [VocabEntry] {
        let newLeft = max(settings.newPerDay - state.stats(for: today).newIntroduced, 0)
        return scheduler.dueCards(entries, states: state.cards, now: now(), newLimit: newLeft)
    }

    func refreshDue() {
        dueCount = dueCards().count
    }

    /// The next moment a card becomes due, for the "all done" screen.
    var nextDue: Date? {
        let t = now()
        return entries.compactMap { e -> Date? in
            guard let s = state.cards[e.word] else { return nil }
            let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: t)!)
            let d = s.lastCorrectDay == today ? max(s.due, tomorrow) : s.due
            return d > t ? d : nil
        }.min()
    }

    // MARK: Quiz

    /// Starts a new session with the cards due now.
    func startSession() {
        session = QuizSession(cards: dueCards(), state: state, scheduler: scheduler, now: now)
        sessionAnswered = 0
        sessionCorrect = 0
        answer = ""
        syncFromSession()
    }

    /// Opens the quiz: keeps a running session, or starts one when the last one finished.
    func openQuiz() {
        reloadVault()
        if session?.isFinished ?? true { startSession() }
    }

    /// Checks the typed answer (Enter). In the wrong-answer view, Enter goes to the next card.
    func submit() {
        switch phase {
        case .asking: check()
        case .wrong, .correct: next()
        case .done: startSession()
        }
    }

    private func check() {
        guard let session, session.current != nil,
              !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let outcome = session.submit(answer) else { return }
        state = session.state
        save()
        sessionAnswered = session.answeredCount
        sessionCorrect = session.correctCount
        refreshDue()
        if outcome.correct {
            phase = .correct(outcome.entry)
            let entry = outcome.entry
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.correctPause) { [weak self] in
                guard let self, self.phase == .correct(entry) else { return }
                self.next()
            }
        } else {
            phase = .wrong(outcome)
        }
    }

    func next() {
        answer = ""
        syncFromSession()
    }

    func skip() {
        session?.skip()
        answer = ""
        syncFromSession()
    }

    private func syncFromSession() {
        current = session?.current
        sessionRemaining = session?.remaining ?? 0
        phase = current == nil ? .done : .asking
    }

    private func save() {
        guard let store else { return }
        do {
            try store.save(state)
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
        }
    }

    // MARK: Stats

    func categoryCounts(days: Int) -> [CategoryCount] {
        GlossStats.categoryCounts(snapshot.mistakes, lastDays: days, today: today, calendar: calendar)
    }

    var topRepeated: [VocabEntry] { GlossStats.topRepeated(snapshot.decks[.spelling] ?? []) }

    func accuracy(days: Int) -> [DayAccuracy] {
        GlossStats.accuracy(state, lastDays: days, today: today, calendar: calendar)
    }
}
