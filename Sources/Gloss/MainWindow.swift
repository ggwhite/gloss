import GlossCore
import SwiftUI

/// The pages of the one main window.
enum Page: String, CaseIterable, Identifiable {
    case overview, quiz, stats, fix, settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .quiz: return "Quiz"
        case .stats: return "Stats"
        case .fix: return "Fix My English"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .quiz: return "character.book.closed.fill"
        case .stats: return "chart.bar.fill"
        case .fix: return "wand.and.stars"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Which page the main window shows. The menu, shortcuts and notifications set it.
final class Navigator: ObservableObject {
    @Published var page: Page = .overview
}

/// Gloss's one window: a glass sidebar and the selected page.
struct MainWindowView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var router: Router
    @EnvironmentObject var nav: Navigator
    @Namespace private var selection
    @State private var hovered: Page?

    static let sidebarWidth: CGFloat = 210

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Self.sidebarWidth)
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
            detail
                .id(nav.page)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(Motion.spring, value: nav.page)
        .frame(minWidth: 900, minHeight: 640)
        .fontDesign(.rounded)
        .background {
            // ⌘W closes the window (a menu bar app has no File menu to provide it).
            Button("Close") { NSApp.keyWindow?.performClose(nil) }
                .keyboardShortcut("w", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear.frame(height: 30) // room for the window buttons
            HStack(spacing: 10) {
                FloatingAppIcon(size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Gloss").font(.system(size: 17, weight: .bold))
                    Text("English from your notes").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 14)

            ForEach(Page.allCases) { page in
                sidebarRow(page)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                shortcutHint(router.openHotKeyLabel(), "open Gloss")
                shortcutHint(router.hotKeyLabel(), "fix selected text")
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            Button { router.quit() } label: { Label("Quit Gloss", systemImage: "power") }
                .buttonStyle(GlassPillStyle(compact: true))
                .padding(.horizontal, 6)
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.black.opacity(0.18))
    }

    @ViewBuilder private func sidebarRow(_ page: Page) -> some View {
        let selected = nav.page == page
        let row = HStack(spacing: 10) {
            Image(systemName: page.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Theme.link)
                .frame(width: 20)
            Text(page.title).font(.system(size: 14, weight: selected ? .bold : .medium))
            Spacer(minLength: 0)
            if page == .quiz, model.dueCount > 0 {
                Text("\(model.dueCount)")
                    .font(.caption.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.bad))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Capsule())

        Button { withAnimation(Motion.spring) { nav.page = page } } label: {
            row
                .background {
                    if selected {
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.accent.opacity(0.75), Theme.violet.opacity(0.55)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .shadow(color: Theme.accent.opacity(0.5), radius: 10, y: 3)
                            .matchedGeometryEffect(id: "selected", in: selection)
                    } else if hovered == page {
                        Capsule().fill(Color.white.opacity(0.07))
                    }
                }
                .offset(x: hovered == page && !selected ? 3 : 0)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(Motion.snappy) { hovered = h ? page : (hovered == page ? nil : hovered) } }
        .keyboardShortcut(KeyEquivalent(Character(String(Page.allCases.firstIndex(of: page)! + 1))), modifiers: .command)
    }

    private func shortcutHint(_ keys: String, _ what: String) -> some View {
        HStack(spacing: 6) {
            Text(keys).font(.caption.weight(.semibold)).foregroundStyle(Theme.link)
            Text(what).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Pages

    private func pageTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func keyTip(_ key: String, _ what: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .glass(RoundedRectangle(cornerRadius: 6, style: .continuous), strength: 0.08)
            Text(what).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var detail: some View {
        switch nav.page {
        case .overview:
            ScrollView {
                HomeView(startQuiz: { nav.page = .quiz }, width: nil, inWindow: true)
                    .padding(.horizontal, 28)
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
            }
        case .quiz:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pageTitle("Quiz", "\(model.dueCount) card\(model.dueCount == 1 ? "" : "s") due · from your 拼字 notes")
                    QuizView(width: 600, showsFooter: false)
                    HStack(spacing: 14) {
                        keyTip("↩", "check / next")
                        keyTip("⌘P", "hear the word")
                        keyTip("⌘1–5", "switch pages")
                    }
                    .padding(.leading, 4)
                }
                .frame(width: 600)
                .padding(.top, 40)
                .frame(maxWidth: .infinity)
            }
        case .stats:
            StatsView()
        case .fix:
            FixPage()
        case .settings:
            VStack(alignment: .leading, spacing: 0) {
                pageTitle("Settings", "Gloss only reads your vault; it never writes to it.")
                    .padding(.horizontal, 28)
                SettingsView(settings: model.settings)
            }
            .padding(.top, 40)
        }
    }
}

/// Fix My English inside the window: type or paste text, press Fix.
struct FixPage: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var fix = FixModel()
    @State private var text = ""
    @State private var task: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Fix My English").font(.system(size: 26, weight: .bold))
                Text("Type or paste English here. In any other app, select text and press the shortcut instead.")
                    .font(.callout).foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("e.g. He go to the office every mornings.")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5).padding(.vertical, 8)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 15))
                        .frame(minHeight: 110)
                }
                .padding(12)
                .glassCard(radius: 22, strength: 0.04)
                HStack {
                    Spacer()
                    Button { run() } label: { Label("Fix", systemImage: "wand.and.stars") }
                        .buttonStyle(GlassPillStyle(tint: Theme.accent, prominent: true))
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                FixView(model: fix, embedded: true, retry: run)
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func run() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        task?.cancel()
        fix.copied = nil
        fix.saveStatus = nil
        fix.phase = .asking(input)
        task = Task { @MainActor in
            do {
                let r = try await ClaudeRunner.fix(input)
                guard !Task.isCancelled else { return }
                fix.phase = .done(input, r)
                await fix.saveToVault(r, settings: model.settings)
            } catch {
                guard !Task.isCancelled else { return }
                fix.phase = .failed(error.localizedDescription, needsPermission: false)
            }
        }
    }
}
