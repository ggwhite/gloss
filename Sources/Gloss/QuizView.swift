import AppKit
import GlossCore
import SwiftUI

/// The menu bar icon with the number of cards due now.
struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "character.book.closed")
            if model.dueCount > 0 {
                Text("\(model.dueCount)").monospacedDigit()
            }
        }
        .accessibilityLabel("Gloss, \(model.dueCount) cards due")
    }
}

/// The spelling quiz shown in the menu bar popover and on the Quiz page.
struct QuizView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var router: Router
    /// Set in the menu: shows a back button to the overview.
    var onBack: (() -> Void)?
    var width: CGFloat = QuizView.width
    /// In the main window the sidebar replaces the footer.
    var showsFooter = true

    @State private var shakes: CGFloat = 0
    /// Bumped to put the cursor back in the answer field (see FocusAnchor).
    @State private var focusTick = 0
    @State private var bursts = 0
    @Environment(\.accessibilityReduceMotion) private var reduce

    static let width: CGFloat = HomeView.width

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            if showsFooter { footer }
        }
        .padding(14)
        .frame(width: width)
        .fontDesign(.rounded)
        .animation(Motion.spring, value: model.phase)
        .animation(Motion.spring, value: model.cardSerial)
        .onAppear {
            model.openQuiz()
            focusField()
        }
        .onChange(of: model.cardSerial) { _, _ in focusField() }
        .onChange(of: model.phase) { _, phase in
            if phase == .asking { focusField() }
            switch phase {
            case .wrong:
                if !reduce { withAnimation(.linear(duration: 0.45)) { shakes += 1 } }
            case .correct:
                bursts += 1
            default:
                break
            }
        }
    }

    /// Puts the cursor in the answer field, so the next card can be typed straight away.
    /// Runs again a moment later, after a new card's views have appeared.
    private func focusField() {
        guard model.phase != .done else { return }
        focusTick += 1
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            if let onBack {
                Button { onBack() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(GlassCircleStyle())
                    .help("Back to the overview")
                    .keyboardShortcut("[", modifiers: .command)
            }
            AppIconView(size: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text("Gloss").font(.system(size: 16, weight: .bold))
                Text("Spelling practice").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if model.sessionAnswered > 0 {
                Label {
                    Text("\(model.sessionCorrect)/\(model.sessionAnswered)")
                        .contentTransition(.numericText())
                } icon: {
                    Image(systemName: "checkmark")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .glass(Capsule(), tint: Theme.good, strength: 0.12)
                .transition(.scale.combined(with: .opacity))
            }
            if model.isPracticing {
                Label("Practice", systemImage: "dumbbell.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .glass(Capsule(), tint: Theme.violet, strength: 0.8)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(model.dueCount) due")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(model.dueCount)))
                    .foregroundStyle(model.dueCount > 0 ? Color.white : Color.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .glass(Capsule(), tint: model.dueCount > 0 ? Theme.bad : nil, strength: model.dueCount > 0 ? 0.8 : 0.1)
            }
        }
        .animation(Motion.spring, value: model.dueCount)
        .animation(Motion.spring, value: model.sessionAnswered)
        .glassGroup(spacing: 8)
    }

    // MARK: Card

    @ViewBuilder private var content: some View {
        if model.entries.isEmpty {
            emptyVault
        } else if let entry = model.current, model.phase != .done {
            card(entry)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        } else {
            doneView
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private var cardTint: Color? {
        switch model.phase {
        case .correct: return Theme.good
        case .wrong: return Theme.bad
        default: return nil
        }
    }

    /// Share of this round done: right answers out of right answers plus cards left.
    private var progress: Double {
        let total = model.sessionCorrect + model.sessionRemaining
        return total == 0 ? 1 : Double(model.sessionCorrect) / Double(total)
    }

    private func card(_ entry: VocabEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressBar(value: progress)

            VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(entry.meaning.isEmpty ? "—" : entry.meaning)
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Spacer()
                SpeakerButton(text: entry.word, size: 34)
                    .keyboardShortcut("p", modifiers: .command)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(CardPrompt.text(for: entry))

            LetterBoxes(word: entry.word, typed: isSolved(entry) ? entry.word : model.answer, solved: isSolved(entry))
            }
            // Only the question slides when the card changes; the text field below stays, and keeps the cursor.
            .id(model.cardSerial)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))

            switch model.phase {
            case .correct(let e):
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.good)
                        .symbolEffect(.bounce, value: bursts)
                    Text(e.word).font(.system(size: 20, weight: .semibold, design: .monospaced))
                    Spacer()
                    Text("Correct").font(.headline).foregroundStyle(Theme.good)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            case .wrong(let outcome):
                WrongAnswerView(outcome: outcome)
                    .transition(.move(edge: .top).combined(with: .opacity))
            default:
                EmptyView()
            }

            HStack(spacing: 8) {
                Image(systemName: "keyboard").foregroundStyle(.secondary)
                TextField("Type the spelling ↩", text: $model.answer)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .autocorrectionDisabled()
                    .background(FocusAnchor(trigger: focusTick, text: model.answer))
                    .onSubmit {
                        model.submit()
                        focusField()
                    }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .glass(Capsule(), tint: Theme.accent, strength: 0.12, interactive: true)
            .overlay(Capsule().stroke(Theme.accent.opacity(0.55), lineWidth: 1.5))

            HStack(spacing: 8) {
                Text(boxLabel(entry)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(model.sessionRemaining) left")
                    .font(.caption).foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(model.sessionRemaining)))
                if case .wrong = model.phase {
                    Button { model.next(); focusField() } label: { Label("Next", systemImage: "return") }
                        .buttonStyle(GlassPillStyle(tint: Theme.accent, prominent: true, compact: true))
                } else {
                    Button { model.skip(); focusField() } label: { Label("Skip", systemImage: "forward.fill") }
                        .buttonStyle(GlassPillStyle(compact: true))
                }
            }
        }
        .padding(16)
        .glassCard(radius: 30, tint: cardTint, strength: 0.08)
        .modifier(Shake(animatableData: shakes))
        .overlay {
            if case .correct = model.phase {
                SparkBurst().id(bursts)
            }
        }
    }

    private func isSolved(_ entry: VocabEntry) -> Bool {
        if case .correct(let e) = model.phase { return e == entry }
        return false
    }

    private func boxLabel(_ entry: VocabEntry) -> String {
        if model.isPracticing { return "Practice · your schedule is not changed" }
        guard let s = model.state.cards[entry.word] else { return "New · missed \(entry.count)×" }
        return "Box \(s.box) of 5 · missed \(entry.count)×"
    }

    private var doneView: some View {
        VStack(spacing: 10) {
            Image(systemName: model.isPracticing ? "star.circle.fill" : "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient(colors: [Theme.good, Theme.blue], startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce, value: model.phase == .done)
            Text(model.isPracticing ? "Practice round done" : "All caught up").font(.title3.weight(.bold))
            if model.sessionAnswered > 0 {
                Text("This round: \(model.sessionCorrect) of \(model.sessionAnswered) right")
                    .foregroundStyle(.secondary)
            }
            if !model.isPracticing, let next = model.nextDue {
                Text("Next review: \(next.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.dueCount > 0 {
                Button("Review \(model.dueCount) due card\(model.dueCount == 1 ? "" : "s")") { model.startSession() }
                    .buttonStyle(GlassPillStyle(tint: Theme.accent, prominent: true))
            }
            PracticeMenu()
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassCard(radius: 30, tint: Theme.good, strength: 0.05)
        .overlay { SparkBurst() }
    }

    private var emptyVault: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No cards found", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warn)
                .font(.headline)
            ForEach(model.snapshot.problems, id: \.self) { Text($0).font(.caption) }
            if model.settings.decks.isEmpty {
                Text("Every deck is turned off in Settings.").font(.caption)
            }
            Text("Vault: \(model.resolvedVaultPath)").font(.caption).foregroundStyle(.secondary)
                .textSelection(.enabled)
            Button("Open Settings…") { router.showSettings() }
                .buttonStyle(GlassPillStyle(tint: Theme.accent, prominent: true, compact: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(radius: 30, tint: Theme.warn, strength: 0.08)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button { router.showStats() } label: { Image(systemName: "chart.bar.fill") }
                .buttonStyle(GlassCircleStyle())
                .help("Stats")
            Button { router.showSettings() } label: { Image(systemName: "gearshape.fill") }
                .buttonStyle(GlassCircleStyle())
                .help("Settings")
            Button { router.fixEnglish() } label: {
                Label("Fix English  \(router.hotKeyLabel())", systemImage: "wand.and.stars")
            }
            .buttonStyle(GlassPillStyle(compact: true))
            Spacer()
            Button { router.quit() } label: { Image(systemName: "power") }
                .buttonStyle(GlassCircleStyle())
                .help("Quit Gloss")
        }
        .glassGroup(spacing: 8)
    }
}

/// A thin glowing bar for how much of the round is done.
struct ProgressBar: View {
    var value: Double

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(colors: [Theme.good, Theme.blue, Theme.violet], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, g.size.width * value))
                    .shadow(color: Theme.blue.opacity(0.7), radius: 6)
            }
        }
        .frame(height: 5)
        .animation(Motion.spring, value: value)
        .accessibilityLabel("Round progress \(Int(value * 100)) percent")
    }
}

/// One box per letter. Typed letters pop into their boxes; a solved word turns mint box by box.
struct LetterBoxes: View {
    let word: String
    let typed: String
    var solved = false

    /// Largest box width; boxes shrink to fit long words. See MECHANICS.md ("Motion").
    static let maxBox: CGFloat = 30
    /// Space between boxes.
    static let gap: CGFloat = 5

    var body: some View {
        let r = CardPrompt.slots(for: word, typed: typed)
        let letterCount = r.slots.filter { if case .separator = $0 { return false } else { return true } }.count
        let separators = r.slots.count - letterCount
        GeometryReader { g in
            // Room left after the letter-count badge (~34) and, when shown, the "+N" badge (~34).
            let reserved: CGFloat = 40 + (r.overflow > 0 ? 38 : 0)
            let gaps = CGFloat(max(r.slots.count - 1, 0)) * Self.gap
            let room = g.size.width - reserved - gaps
            let box = min(Self.maxBox, max(12, room / (CGFloat(letterCount) + CGFloat(separators) * 0.35)))
            HStack(spacing: Self.gap) {
                ForEach(Array(r.slots.enumerated()), id: \.offset) { i, slot in
                    cell(slot, index: i, size: box)
                }
                if r.overflow > 0 {
                    Text("+\(r.overflow)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.bad))
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer(minLength: 0)
                Text("\(letterCount)")
                    .font(.caption.weight(.bold)).monospacedDigit()
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .glass(Capsule(), strength: 0.1)
                    .help("\(letterCount) letters")
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: Self.maxBox * 1.3)
        .animation(Motion.snappy, value: typed)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func cell(_ slot: LetterSlot, index: Int, size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        switch slot {
        case .separator:
            Color.clear.frame(width: size * 0.35, height: size * 1.3)
        default:
            ZStack {
                shape.fill(fill(slot))
                shape.stroke(stroke(slot), lineWidth: 1)
                switch slot {
                case .typed(let c):
                    Text(String(c))
                        .font(.system(size: size * 0.66, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                        .id("\(index)\(c)")
                case .hint(let c):
                    Text(String(c))
                        .font(.system(size: size * 0.66, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.link.opacity(0.8))
                default:
                    Capsule().fill(Color.white.opacity(0.25)).frame(width: size * 0.4, height: 2).offset(y: size * 0.42)
                }
            }
            .frame(width: size, height: size * 1.3)
            // A solved word hops box by box and glows; the boxes keep their size so long words don't crowd.
            .offset(y: solved ? -3 : 0)
            .shadow(color: Theme.good.opacity(solved ? 0.55 : 0), radius: solved ? 6 : 0)
            .animation(Motion.spring.delay(solved ? Double(index) * 0.035 : 0), value: solved)
        }
    }

    private func fill(_ slot: LetterSlot) -> Color {
        if solved { return Theme.good.opacity(0.55) }
        switch slot {
        case .typed: return Theme.accent.opacity(0.45)
        default: return Color.white.opacity(0.06)
        }
    }

    private func stroke(_ slot: LetterSlot) -> Color {
        if solved { return Theme.good }
        switch slot {
        case .typed: return Theme.accent.opacity(0.9)
        case .hint: return Theme.link.opacity(0.5)
        default: return Color.white.opacity(0.14)
        }
    }
}

/// The right spelling with wrong letters marked, what was typed, and the memory hint.
struct WrongAnswerView: View {
    let outcome: AnswerOutcome
    @State private var popped = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Not quite", systemImage: "xmark.circle.fill")
                .foregroundStyle(Theme.bad)
                .font(.headline)
                .symbolEffect(.bounce, value: popped)
            HStack(alignment: .center, spacing: 8) {
                Text("Right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                RightSpelling(word: outcome.entry.word, wrong: outcome.wrongMask, popped: popped)
                Spacer(minLength: 0)
                SpeakerButton(text: outcome.entry.word, size: 26)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("You").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                TypedSpelling(ops: outcome.diff)
            }
            if !outcome.entry.hint.isEmpty {
                Label(outcome.entry.hint, systemImage: "lightbulb.fill")
                    .font(.callout)
                    .symbolRenderingMode(.multicolor)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glass(RoundedRectangle(cornerRadius: 20, style: .continuous), tint: Theme.warn, strength: 0.16)
            }
            Text("This card comes back later in this round.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .onAppear { withAnimation(Motion.spring.delay(0.15)) { popped = true } }
    }
}

struct RightSpelling: View {
    let word: String
    let wrong: [Bool]
    var popped = true

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(word.enumerated()), id: \.offset) { i, ch in
                let bad = i < wrong.count && wrong[i]
                Text(String(ch))
                    .font(.system(size: 22, weight: bad ? .heavy : .semibold, design: .monospaced))
                    .foregroundStyle(bad ? Color.white : Theme.good)
                    .padding(.horizontal, 2)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(bad ? Theme.bad.opacity(0.85) : Color.clear))
                    .scaleEffect(bad && popped ? 1.15 : 1)
                    .animation(Motion.spring.delay(Double(i) * 0.02), value: popped)
            }
        }
        .accessibilityLabel(word)
    }
}

struct TypedSpelling: View {
    let ops: [DiffOp]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(ops.enumerated()), id: \.offset) { _, op in
                switch op {
                case .same(let c):
                    letter(String(c), color: .secondary, strike: false)
                case .substituted(_, let t), .extra(let t):
                    letter(String(t), color: Theme.bad, strike: true)
                case .missing:
                    letter("_", color: Theme.warn, strike: false)
                }
            }
        }
    }

    private func letter(_ s: String, color: Color, strike: Bool) -> some View {
        Text(s)
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .strikethrough(strike, color: Theme.bad)
            .foregroundStyle(color)
    }
}

/// The extra practice choices shown when the day's reviews are done.
struct PracticeMenu: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Keep practising").font(.headline)
                Spacer()
                Text("Doesn't change your schedule").font(.caption2).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                option("Hardest \(Practice.roundSize)", "flame.fill", "Words you miss most", [Theme.warn, Theme.bad],
                       enabled: model.practiceCount(.hardest) > 0) { model.startPractice(.hardest) }
                option("Random \(Practice.roundSize)", "shuffle", "A mixed review", [Theme.link, Theme.blue],
                       enabled: model.practiceCount(.random) > 0) { model.startPractice(.random) }
                let todayCount = model.practiceCount(.today)
                option("Today's words", "arrow.counterclockwise", todayCount == 0 ? "None answered yet" : "\(todayCount) answered today",
                       [Theme.good, Theme.blue], enabled: todayCount > 0) { model.startPractice(.today) }
                let unseen = model.unseenCount
                option(unseen == 0 ? "Learn new" : "Learn \(min(Practice.roundSize, unseen)) new", "sparkles",
                       unseen == 0 ? "You've seen every card" : "Adds them to your schedule",
                       [Theme.violet, Theme.accent], enabled: unseen > 0) { model.learnMoreNew() }
            }
        }
    }

    private func option(_ title: String, _ icon: String, _ subtitle: String, _ colors: [Color],
                        enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .bold))
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 16, strength: 0.04)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .hoverLift(radius: 16)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}
