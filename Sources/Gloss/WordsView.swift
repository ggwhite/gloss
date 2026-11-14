import GlossCore
import SwiftUI

/// The Words page: every word in your notes with its meaning, an example sentence, your memory hint and
/// where it is in the schedule. Missing examples can be written by Claude (kept in Gloss, not the vault).
struct WordsView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var deck: Deck?
    @State private var sort: Sort = .needsPractice
    @State private var gettingOne: String?

    enum Sort: String, CaseIterable, Identifiable {
        case needsPractice = "Needs practice"
        case mostMissed = "Most missed"
        case az = "A–Z"
        var id: String { rawValue }
    }

    var body: some View {
        let all = model.allWords
        let shown = filtered(all)
        let withExample = all.filter { !$0.example.isEmpty }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(total: all.count, withExample: withExample)
                controls(all)
                if shown.isEmpty {
                    Text(query.isEmpty ? "No words in this deck." : "No word matches “\(query)”.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
                LazyVStack(spacing: 10) {
                    ForEach(shown) { info in row(info) }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .fontDesign(.rounded)
        .onAppear { model.loadNotes() }
    }

    // MARK: Header

    private func header(total: Int, withExample: Int) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Words").font(.system(size: 26, weight: .bold))
                Text("\(total) words · \(withExample) with an example")
                    .font(.callout).foregroundStyle(.secondary)
                if let err = model.exampleError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if let job = model.exampleJob {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: Double(job.done), total: Double(max(job.total, 1)))
                        .frame(width: 180)
                        .tint(Theme.accent)
                    Text("Claude is writing examples… \(job.done)/\(job.total) groups")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if withExample < total {
                Button {
                    Task { await model.fillMissingExamples() }
                } label: {
                    Label("Fill \(total - withExample) missing examples", systemImage: "sparkles")
                }
                .buttonStyle(GlassPillStyle(tint: Theme.accent, prominent: true, compact: true))
                .help("Claude writes an example sentence (and a meaning where one is missing) for each word without one. They are kept in Gloss, not in your notes.")
            } else {
                Label("Every word has an example", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.good)
            }
        }
    }

    private func controls(_ all: [WordInfo]) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search words, meanings, examples", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .glass(Capsule(), strength: 0.06, interactive: true)
            .frame(maxWidth: 300)

            Picker("Deck", selection: $deck) {
                Text("All \(all.count)").tag(Deck?.none)
                ForEach(Deck.allCases) { d in
                    Text("\(d.shortTitle) \(all.filter { $0.entry.deck == d }.count)").tag(Deck?.some(d))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker("Sort", selection: $sort) {
                ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .frame(width: 140)
        }
    }

    private func filtered(_ all: [WordInfo]) -> [WordInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = all.filter { info in
            (deck == nil || info.entry.deck == deck) &&
            (q.isEmpty || info.entry.word.lowercased().contains(q) || info.meaning.lowercased().contains(q)
             || info.example.lowercased().contains(q) || info.hint.lowercased().contains(q))
        }
        switch sort {
        case .az:
            return list.sorted { $0.entry.word.lowercased() < $1.entry.word.lowercased() }
        case .mostMissed:
            return list.sorted { $0.entry.count != $1.entry.count ? $0.entry.count > $1.entry.count : $0.entry.word < $1.entry.word }
        case .needsPractice:
            // Due first, then by box (new and box 1 first), then most missed.
            func rank(_ i: WordInfo) -> (Int, Int, Int) {
                let s = model.state.cards[i.entry.word]
                let due = model.scheduler.isDue(s, now: model.now()) ? 0 : 1
                return (due, s?.box ?? 0, -i.entry.count)
            }
            return list.sorted { a, b in
                let ra = rank(a), rb = rank(b)
                return ra != rb ? ra < rb : a.entry.word < b.entry.word
            }
        }
    }

    // MARK: Row

    private func status(_ info: WordInfo) -> (String, Color) {
        guard let s = model.state.cards[info.entry.word] else { return ("New", Theme.link) }
        if model.scheduler.isDue(s, now: model.now()) { return ("Due", Theme.bad) }
        return ("Box \(s.box)", s.box >= 4 ? Theme.good : Theme.violet)
    }

    private func row(_ info: WordInfo) -> some View {
        let (label, color) = status(info)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(info.entry.word)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)
                Text(info.meaning.isEmpty ? "—" : info.meaning)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(2)
                Spacer(minLength: 8)
                if info.entry.count > 1 {
                    Text("missed \(info.entry.count)×").font(.caption2).foregroundStyle(.secondary)
                }
                Text(info.entry.deck.shortTitle)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .glass(Capsule(), strength: 0.08)
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(color.opacity(0.85)))
                SpeakerButton(text: info.entry.word, size: 24)
            }
            if info.example.isEmpty {
                HStack(spacing: 8) {
                    Text("No example yet").font(.callout).italic().foregroundStyle(.tertiary)
                    if gettingOne == info.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Get one") {
                            gettingOne = info.id
                            Task { await model.fillExample(for: info); gettingOne = nil }
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.link)
                        .disabled(model.exampleJob != nil)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.quote").font(.caption).foregroundStyle(.secondary).padding(.top, 2)
                    Text(highlight(info.example, word: info.entry.word))
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { Pronouncer.shared.say(info.example) } label: { Image(systemName: "speaker.wave.2") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Hear the sentence")
                }
            }
            if !info.hint.isEmpty {
                Label(info.hint, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18, strength: 0.03)
    }

    /// The example with the word in bold mint.
    private func highlight(_ sentence: String, word: String) -> AttributedString {
        var s = AttributedString(sentence)
        var search = s.startIndex..<s.endIndex
        while let r = s[search].range(of: word, options: .caseInsensitive) {
            s[r].foregroundColor = Theme.good
            s[r].font = .callout.weight(.bold)
            search = r.upperBound..<s.endIndex
        }
        return s
    }
}

extension Deck {
    /// A short label for chips and filters.
    var shortTitle: String {
        switch self {
        case .spelling: return "Spelling"
        case .usage: return "Word choice"
        case .asked: return "New words"
        }
    }
}
