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

/// The spelling quiz shown in the menu bar popover (and in the quiz window).
struct QuizView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var router: Router
    @FocusState private var fieldFocused: Bool

    static let width: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .padding(16)
        .frame(width: Self.width)
        .onAppear {
            model.openQuiz()
            DispatchQueue.main.async { fieldFocused = true }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "character.book.closed")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text("Gloss").font(.headline)
            Spacer()
            if model.sessionAnswered > 0 {
                Text("\(model.sessionCorrect)/\(model.sessionAnswered) right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(model.dueCount) due")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(model.dueCount > 0 ? Color.red.opacity(0.85) : Color.secondary.opacity(0.25)))
                .foregroundStyle(model.dueCount > 0 ? Color.white : Color.secondary)
        }
    }

    @ViewBuilder private var content: some View {
        if model.entries.isEmpty {
            emptyVault
        } else if let entry = model.current, model.phase != .done {
            card(entry)
        } else {
            doneView
        }
    }

    private func card(_ entry: VocabEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.meaning.isEmpty ? "—" : entry.meaning)
                    .font(.system(size: 26, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text("→").font(.title2).foregroundStyle(.secondary)
                Text(CardPrompt.mask(entry.word))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .kerning(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("(\(CardPrompt.letterCount(entry.word)))")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(CardPrompt.text(for: entry))

            switch model.phase {
            case .correct(let e):
                Label {
                    Text("Correct — \(e.word)").font(.title3.weight(.semibold))
                } icon: {
                    Image(systemName: "checkmark.circle.fill").font(.title2)
                }
                .foregroundStyle(.green)
            case .wrong(let outcome):
                WrongAnswerView(outcome: outcome)
            default:
                EmptyView()
            }

            TextField("Type the spelling ↩", text: $model.answer)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 18, design: .monospaced))
                .autocorrectionDisabled()
                .focused($fieldFocused)
                .onSubmit {
                    model.submit()
                    fieldFocused = true
                }

            HStack {
                Text(boxLabel(entry)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(model.sessionRemaining) left").font(.caption).foregroundStyle(.secondary)
                if case .wrong = model.phase {
                    Button("Next ↩") { model.next(); fieldFocused = true }
                        .controlSize(.small)
                } else {
                    Button("Skip") { model.skip(); fieldFocused = true }
                        .controlSize(.small)
                }
            }
        }
    }

    private func boxLabel(_ entry: VocabEntry) -> String {
        guard let s = model.state.cards[entry.word] else { return "New · missed \(entry.count)×" }
        return "Box \(s.box) of 5 · missed \(entry.count)×"
    }

    private var doneView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundStyle(.green)
            Text("All caught up").font(.title3.weight(.semibold))
            if model.sessionAnswered > 0 {
                Text("This round: \(model.sessionCorrect) of \(model.sessionAnswered) right")
                    .foregroundStyle(.secondary)
            }
            if let next = model.nextDue {
                Text("Next card: \(next.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.dueCount > 0 {
                Button("Study \(model.dueCount) more") { model.startSession() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var emptyVault: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("No cards found", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.headline)
            ForEach(model.snapshot.problems, id: \.self) { Text($0).font(.caption) }
            if model.settings.decks.isEmpty {
                Text("Every deck is turned off in Settings.").font(.caption)
            }
            Text("Vault: \(model.resolvedVaultPath)").font(.caption).foregroundStyle(.secondary)
                .textSelection(.enabled)
            Button("Open Settings…") { router.showSettings() }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button { router.showStats() } label: { Label("Stats", systemImage: "chart.bar") }
            Button { router.showSettings() } label: { Label("Settings", systemImage: "gearshape") }
            Button { router.fixEnglish() } label: {
                Label("Fix English \(router.hotKeyLabel())", systemImage: "wand.and.stars")
            }
            Spacer()
            Button { router.quit() } label: { Image(systemName: "power") }
                .help("Quit Gloss")
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}

/// The right spelling with wrong letters marked, what was typed, and the memory hint.
struct WrongAnswerView: View {
    let outcome: AnswerOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Not quite", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Right").font(.caption).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                RightSpelling(word: outcome.entry.word, wrong: outcome.wrongMask)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("You").font(.caption).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                TypedSpelling(ops: outcome.diff)
            }
            if !outcome.entry.hint.isEmpty {
                Label(outcome.entry.hint, systemImage: "lightbulb.fill")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.18)))
            }
            Text("This card comes back later in this round.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct RightSpelling: View {
    let word: String
    let wrong: [Bool]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(word.enumerated()), id: \.offset) { i, ch in
                let bad = i < wrong.count && wrong[i]
                Text(String(ch))
                    .font(.system(size: 22, weight: bad ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(bad ? Color.red : Color.green)
                    .padding(.horizontal, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(bad ? Color.red.opacity(0.18) : Color.clear))
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
                    letter(String(t), color: .red, strike: true)
                case .missing:
                    letter("_", color: .orange, strike: false)
                }
            }
        }
    }

    private func letter(_ s: String, color: Color, strike: Bool) -> some View {
        Text(s)
            .font(.system(size: 16, design: .monospaced))
            .strikethrough(strike, color: .red)
            .foregroundStyle(color)
    }
}
