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
    @Published var answer = "" {
        didSet {
            // Typing during the green-check pause starts the next card at once, keeping what was typed.
            if case .correct = phase, !answer.isEmpty, oldValue.isEmpty { next(keepAnswer: true) }
        }
    }
    @Published private(set) var sessionRemaining = 0
    @Published private(set) var sessionAnswered = 0
    @Published private(set) var sessionCorrect = 0
    @Published private(set) var lastSaveError: String?
    /// The menu shows the overview, or the quiz after "Start Quiz".
    @Published var showingQuiz = false
    /// Changes each time a new card is put in front (drives the card's slide-in).
    @Published private(set) var cardSerial = 0
    /// Set during extra practice (nil for the scheduled reviews).
    @Published private(set) var practiceKind: PracticeKind?

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

    /// Words added by hand while Gloss may not write to the vault (nil: none kept).
    let wordStore: NewWordStore?
    /// Meanings and examples Claude wrote for words whose table has no example column (nil: none kept).
    let noteStore: WordNoteStore?
    @Published private(set) var notes: [String: WordNote] = [:]
    /// The "Fill missing examples" job while it runs.
    @Published private(set) var exampleJob: ExampleJob?

    struct ExampleJob: Equatable {
        var done = 0
        var total: Int
        var failed = 0
        var lastError: String?
    }

    init(settings: AppSettings, store: StateStore?, fixedSnapshot: VaultSnapshot? = nil, initialState: GlossState? = nil,
         wordStore: NewWordStore? = nil, noteStore: WordNoteStore? = nil,
         calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.wordStore = wordStore
        self.noteStore = noteStore
        self.settings = settings
        self.store = store
        self.fixedSnapshot = fixedSnapshot
        self.calendar = calendar
        self.now = now
        state = initialState ?? store?.load() ?? GlossState()
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
        mergeAddedWords()
        loadNotes()
        refreshDue()
        if session == nil || phase == .done { startSession() }
    }

    private var lastDecks: Set<Deck> = []
    private var lastPath = ""
    private func settingsChanged() {
        objectWillChange.send()
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
        let day = state.stats(for: today)
        let newLeft = max(settings.newPerDay + day.extraNew - day.newIntroduced, 0)
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
        practiceKind = nil
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
        case .wrong: copyOrNext()
        case .correct: next()
        case .done: startSession()
        }
    }

    // MARK: Words page

    /// Every word in every deck (on or off), once each, with its meaning and example.
    var allWords: [WordInfo] {
        WordInfo.build(snapshot.entries(for: Set(Deck.allCases)), notes: notes)
    }

    func loadNotes() {
        notes = noteStore?.load() ?? [:]
    }

    /// Asks Claude for the missing examples (and meanings), 20 words a question, 3 questions at a time.
    func fillMissingExamples() async {
        guard exampleJob == nil, let noteStore else { return }
        let batches = ExampleBatch.batches(allWords)
        guard !batches.isEmpty else { return }
        exampleJob = ExampleJob(total: batches.count)
        await withTaskGroup(of: (ok: Bool, notes: [String: WordNote], error: String?).self) { group in
            var next = 0
            func launch() {
                guard next < batches.count else { return }
                let batch = batches[next]
                next += 1
                group.addTask {
                    let words = batch.map { (word: $0.entry.word, meaning: $0.meaning) }
                    do {
                        let reply = try await ClaudeRunner.ask(ExampleBatch.prompt(for: words))
                        return (true, try ExampleBatch.parse(reply, asked: words.map(\.word)), nil)
                    } catch {
                        return (false, [:], error.localizedDescription)
                    }
                }
            }
            for _ in 0..<Self.exampleParallel { launch() }
            for await r in group {
                if !r.notes.isEmpty, let all = try? noteStore.merge(r.notes) { notes = all }
                exampleJob?.done += 1
                if !r.ok { exampleJob?.failed += 1; exampleJob?.lastError = r.error }
                launch()
            }
        }
        let failed = exampleJob?.failed ?? 0
        let lastError = exampleJob?.lastError
        exampleJob = nil
        if failed > 0 { exampleError = "\(failed) group\(failed == 1 ? "" : "s") failed: \(lastError ?? "")" } else { exampleError = nil }
    }

    /// Claude questions running at once while filling examples. See MECHANICS.md.
    static let exampleParallel = 3
    @Published var exampleError: String?

    /// One word's example (the Words page's "Get one").
    func fillExample(for info: WordInfo) async {
        guard let noteStore else { return }
        let w = (word: info.entry.word, meaning: info.meaning)
        do {
            let reply = try await ClaudeRunner.ask(ExampleBatch.prompt(for: [w]))
            let got = try ExampleBatch.parse(reply, asked: [w.word])
            if let all = try? noteStore.merge(got) { notes = all }
            exampleError = got.isEmpty ? "Claude gave no example for “\(w.word)”." : nil
        } catch {
            exampleError = error.localizedDescription
        }
    }

    // MARK: New words

    /// Adds the words kept in Gloss to the New words deck (a word already in the notes is kept once).
    private func mergeAddedWords() {
        guard let added = wordStore?.load(), !added.isEmpty else { return }
        var deck = snapshot.decks[.asked] ?? []
        let known = Set(deck.map { $0.word.lowercased() })
        deck += added.map(\.entry).filter { !known.contains($0.word.lowercased()) }
        snapshot.decks[.asked] = deck
    }

    enum AddWordOutcome: Equatable {
        case savedToNotes
        case savedInGloss(note: String?)
        case alreadyInNotes
        case failed(String)
    }

    /// Saves a new word: into the `## 問過的字` table of 單字.md when Gloss may write to the notes
    /// (Settings → Write to my notes), otherwise in Gloss's own list. Either way it joins the New words deck.
    func addWord(_ word: String, meaning: String, example: String) -> AddWordOutcome {
        let w = Markdown.collapseWhitespace(word), m = Markdown.collapseWhitespace(meaning)
        let ex = Markdown.collapseWhitespace(example)
        guard !w.isEmpty, !m.isEmpty else { return .failed("Type the word and its meaning.") }
        var note: String?
        if settings.saveFixMistakes {
            let url = Vault.resolve(settings.vaultPath).appendingPathComponent(Vault.vocabFile)
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                switch AskedTable.add(word: w, meaning: m, example: ex, to: text) {
                case .success(let updated):
                    do {
                        try updated.write(to: url, atomically: true, encoding: .utf8)
                        reloadVault(force: true)
                        return .savedToNotes
                    } catch {
                        note = "Couldn't write 單字.md (\(error.localizedDescription)); kept in Gloss instead."
                    }
                case .failure(.alreadyThere):
                    return .alreadyInNotes
                case .failure(.noSection):
                    note = "單字.md has no “## 問過的字” table; kept in Gloss instead."
                case .failure(.unexpectedColumns(let cols)):
                    note = "The “## 問過的字” table has other columns (\(cols.joined(separator: " | "))); kept in Gloss instead."
                }
            } else {
                note = "Couldn't read 單字.md; kept in Gloss instead."
            }
        }
        guard let wordStore else { return .failed("No place to keep the word.") }
        do {
            try wordStore.add(NewWord(word: w, meaning: m, example: ex, added: now()))
        } catch {
            return .failed(error.localizedDescription)
        }
        reloadVault(force: true)
        return .savedInGloss(note: note)
    }

    /// The New words cards, newest last.
    var newWords: [VocabEntry] { snapshot.decks[.asked] ?? [] }

    /// A practice round with just these words (it doesn't change the schedule).
    func practise(_ words: [VocabEntry]) {
        guard !words.isEmpty else { return }
        practiceKind = .today
        session = QuizSession(cards: words, state: state, scheduler: scheduler, practice: true, now: now)
        sessionAnswered = 0
        sessionCorrect = 0
        answer = ""
        syncFromSession()
    }

    // MARK: Copy drill

    /// After a wrong answer: the right spelling to type `settings.copyReps` times (nil when off or skipped).
    @Published private(set) var drill: CopyDrill?
    /// Goes up on each copy with a mistake (the card shakes).
    @Published private(set) var drillMisses = 0

    /// How long "Got it" shows after the last copy before the next card. See MECHANICS.md.
    static let drillDonePause: Double = 0.6

    /// Enter in the wrong-answer view: counts a copy, or moves on when the drill is off, done or skipped
    /// (Enter on an empty field).
    private func copyOrNext() {
        guard var d = drill, !d.isFinished else { next(); return }
        let result = d.submit(answer)
        drill = d
        switch result {
        case .empty:
            next()
        case .wrong:
            drillMisses += 1
            answer = ""
        case .counted:
            answer = ""
            if settings.speakOnAnswer { Pronouncer.shared.say(d.word) }
        case .finished:
            answer = ""
            if settings.speakOnAnswer { Pronouncer.shared.say(d.word) }
            let serial = cardSerial
            let work = DispatchWorkItem { [weak self] in
                guard let self, case .wrong = self.phase, self.cardSerial == serial else { return }
                self.next()
            }
            advanceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Motion.seconds(Self.drillDonePause), execute: work)
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
        if settings.speakOnAnswer { Pronouncer.shared.say(outcome.entry.word) }
        if outcome.correct {
            phase = .correct(outcome.entry)
            answer = "" // the field is free for the next card at once
            // Move on after the green check, unless something else already moved on (Enter, typing, Skip).
            let serial = cardSerial
            let work = DispatchWorkItem { [weak self] in
                guard let self, case .correct = self.phase, self.cardSerial == serial else { return }
                self.next()
            }
            advanceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Motion.seconds(Self.correctPause), execute: work)
        } else {
            phase = .wrong(outcome)
            if settings.copyReps > 0 {
                drill = CopyDrill(word: outcome.entry.word, required: min(settings.copyReps, CopyDrill.maxReps))
                answer = "" // a fresh field for the copies
            }
        }
    }

    func next(keepAnswer: Bool = false) {
        if !keepAnswer { answer = "" }
        syncFromSession()
    }

    func skip() {
        session?.skip()
        answer = ""
        syncFromSession()
    }

    /// The pending "next card after the green check"; cancelled whenever the card changes another way.
    private var advanceWork: DispatchWorkItem?

    private func syncFromSession() {
        advanceWork?.cancel()
        advanceWork = nil
        drill = nil
        let previous = current
        current = session?.current
        cardSerial += 1
        sessionRemaining = session?.remaining ?? 0
        phase = current == nil ? .done : .asking
        if settings.speakOnShow, let c = current, c != previous { Pronouncer.shared.say(c.word) }
    }

    /// Says the current card's word (the speaker button).
    func pronounceCurrent() {
        if let c = current { Pronouncer.shared.say(c.word) }
    }

    // MARK: Extra practice

    var isPracticing: Bool { practiceKind != nil }

    /// Cards never answered yet in the decks that are on.
    var unseenCount: Int { entries.filter { state.cards[$0.word] == nil }.count }

    func practiceCount(_ kind: PracticeKind) -> Int {
        Practice.available(kind, from: entries, states: state.cards, today: today, calendar: calendar)
    }

    /// Starts a practice round. Answers are checked and counted, but the schedule does not change.
    func startPractice(_ kind: PracticeKind) {
        let cards = Practice.pick(kind, from: entries, states: state.cards, today: today, calendar: calendar)
        guard !cards.isEmpty else { return }
        practiceKind = kind
        session = QuizSession(cards: cards, state: state, scheduler: scheduler, practice: true, now: now)
        sessionAnswered = 0
        sessionCorrect = 0
        answer = ""
        syncFromSession()
    }

    /// Adds `Practice.roundSize` new cards to today's schedule (past the daily limit) and starts them.
    func learnMoreNew() {
        var day = state.stats(for: today)
        day.extraNew += Practice.roundSize
        state.daily[today.iso] = day
        save()
        refreshDue()
        startSession()
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

    // MARK: Overview

    var weekAnswers: (answered: Int, correct: Int) {
        accuracy(days: 7).reduce((0, 0)) { ($0.0 + $1.answered, $0.1 + $1.correct) }
    }

    var health: EnglishHealth {
        let w = weekAnswers
        return Overview.health(answered: w.answered, correct: w.correct, due: dueCount)
    }

    var streak: (current: Int, best: Int) { Overview.streak(state, today: today, calendar: calendar) }

    var boxCounts: [Int] { Overview.boxCounts(entries, states: state.cards) }

    /// Due cards split into never-answered and review cards.
    var dueSplit: (new: Int, review: Int) {
        let due = dueCards()
        let new = due.filter { state.cards[$0.word] == nil }.count
        return (new, due.count - new)
    }

    var weekCategories: [CategoryCount] { categoryCounts(days: 7) }

    func recommendation(fixShortcut: String) -> Recommendation {
        Overview.recommend(due: dueCards(), week: weekCategories, fixShortcut: fixShortcut, canPractise: !entries.isEmpty)
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
