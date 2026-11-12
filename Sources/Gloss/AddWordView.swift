import GlossCore
import SwiftUI

/// "Add Word": a word you met and didn't know. Claude fills in the meaning and an example; you can edit
/// both before adding it to the New words deck.
struct AddWordView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: Navigator
    @State private var word = ""
    @State private var meaning = ""
    @State private var example = ""
    @State private var looking = false
    @State private var lookTask: Task<Void, Never>?
    @State private var status: (text: String, good: Bool)?
    @State private var lookTime: Double?
    @State private var focusTick = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add a New Word").font(.system(size: 26, weight: .bold))
                    Text("A word you met and didn't know. Press Enter to let Claude fill in the meaning and an example; edit them if you like.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    field("English word", text: $word, icon: "character.cursor.ibeam", big: true) { lookUp() }
                        .background(FocusAnchor(trigger: focusTick, text: word))
                    HStack(spacing: 8) {
                        Button { lookUp() } label: {
                            if looking { ProgressView().controlSize(.small) } else { Label("Look Up", systemImage: "sparkle.magnifyingglass") }
                        }
                        .buttonStyle(GlassPillStyle(compact: true))
                        .disabled(word.trimmingCharacters(in: .whitespaces).isEmpty || looking)
                        if let lookTime {
                            Text(String(format: "answered in %.1f s", lookTime)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !word.isEmpty { SpeakerButton(text: word, size: 26) }
                    }
                    field("中文意思 (meaning)", text: $meaning, icon: "character.book.closed") { add() }
                    field("Example sentence (shown after a mistake)", text: $example, icon: "text.quote") { add() }
                    HStack {
                        if let status {
                            Label(status.text, systemImage: status.good ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(status.good ? Theme.good : Theme.warn)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button { add() } label: { Label("Add Word", systemImage: "plus") }
                            .buttonStyle(GlassPillStyle(tint: Theme.accent, prominent: true))
                            .keyboardShortcut(.return, modifiers: .command)
                            .disabled(word.trimmingCharacters(in: .whitespaces).isEmpty || meaning.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(16)
                .glassCard(radius: 24, strength: 0.04)

                recent
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .fontDesign(.rounded)
        .onAppear { focusTick += 1 }
    }

    private func field(_ title: String, text: Binding<String>, icon: String, big: Bool = false,
                       submit: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 18)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .font(big ? .system(size: 20, weight: .semibold, design: .monospaced) : .system(size: 15))
                .autocorrectionDisabled()
                .onSubmit(submit)
        }
        .padding(.horizontal, 14).padding(.vertical, big ? 11 : 9)
        .glass(Capsule(), tint: big ? Theme.accent : nil, strength: big ? 0.12 : 0.06, interactive: true)
    }

    // MARK: Recent words

    private var recent: some View {
        let words = Array(model.newWords.suffix(8).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("New words").font(.headline)
                Text("\(model.newWords.count)").font(.caption.weight(.bold)).monospacedDigit()
                    .padding(.horizontal, 7).padding(.vertical, 2).glass(Capsule(), strength: 0.1)
                Spacer()
                Button { practise(words) } label: { Label("Practise These", systemImage: "play.fill") }
                    .buttonStyle(GlassPillStyle(compact: true))
                    .disabled(words.isEmpty)
            }
            if words.isEmpty {
                Text("No new words yet.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(words, id: \.word) { e in
                HStack(spacing: 10) {
                    SpeakerButton(text: e.word, size: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.word).font(.system(.body, design: .monospaced).weight(.semibold))
                        Text(e.hint.isEmpty ? e.meaning : "\(e.meaning) · \(e.hint)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .glassCard(radius: 24, strength: 0.03)
    }

    // MARK: Actions

    private func lookUp() {
        let w = word.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty, !looking else { return }
        looking = true
        status = nil
        lookTime = nil
        let started = Date()
        lookTask = Task { @MainActor in
            defer { looking = false }
            do {
                let r = try await ClaudeRunner.lookUp(w)
                lookTime = Date().timeIntervalSince(started)
                if r.word.lowercased() != w.lowercased() {
                    status = ("Spelling corrected from “\(w)”.", true)
                }
                word = r.word
                meaning = r.meaning_zh
                example = r.example
            } catch {
                status = (error.localizedDescription, false)
            }
        }
    }

    private func add() {
        switch model.addWord(word, meaning: meaning, example: example) {
        case .savedToNotes:
            status = ("Added “\(word)” to 單字.md → ## 問過的字.", true)
        case .savedInGloss(let note):
            status = (note ?? "Added “\(word)” to New words (kept in Gloss; turn on “Write to my notes” to save it in 單字.md).", note == nil)
        case .alreadyInNotes:
            status = ("“\(word)” is already in ## 問過的字.", false)
            return
        case .failed(let why):
            status = (why, false)
            return
        }
        word = ""
        meaning = ""
        example = ""
        lookTime = nil
        focusTick += 1
    }

    private func practise(_ words: [VocabEntry]) {
        model.practise(words)
        nav.page = .quiz
    }
}
