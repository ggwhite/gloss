import GlossCore
import SwiftUI

/// What the menu bar popover shows: the overview, or the quiz.
struct PopoverRoot: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            if model.showingQuiz {
                QuizView(onBack: { model.showingQuiz = false })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                HomeView(startQuiz: { model.showingQuiz = true })
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.showingQuiz)
    }
}

/// One info tile: icon, title, coloured subtitle, content, and an optional text button at the bottom right.
struct Tile<Content: View>: View {
    let icon: String
    var iconColors: [Color] = [Theme.blue, Theme.violet]
    let title: String
    var subtitle: String?
    var subtitleColor: Color = .secondary
    var trailing: String?
    var trailingColor: Color = Theme.bad
    var actionTitle: String?
    var action: () -> Void = {}
    @ViewBuilder var content: Content
    @State private var bounced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.bounce, value: bounced)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(subtitleColor).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if let trailing {
                    Text(trailing).font(.caption.weight(.semibold)).foregroundStyle(trailingColor)
                }
            }
            content
            if let actionTitle {
                HStack {
                    Spacer()
                    Button(actionTitle, action: action)
                        .buttonStyle(.plain)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.link)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard(radius: 18, strength: 0.03)
        .hoverLift(radius: 18)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { bounced = true } }
    }
}

/// The overview: English health, tiles, today's recommendation and the footer.
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var router: Router
    var startQuiz: () -> Void
    /// Fixed width in the menu; nil fills the window page.
    var width: CGFloat? = HomeView.width
    /// In the main window the sidebar replaces the footer.
    var inWindow = false

    static let width: CGFloat = 420

    /// Bars grow from zero shortly after the overview appears.
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header.appearIn(delay: 0)
            if !model.settings.welcomeDone {
                welcome
                    .appearIn(delay: 0.03)
                    .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.9).combined(with: .opacity)))
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 10) {
                    dueTile.appearIn(delay: Motion.stagger * 1)
                    streakTile.appearIn(delay: Motion.stagger * 3)
                    mistakesTile.appearIn(delay: Motion.stagger * 5)
                }
                VStack(spacing: 10) {
                    accuracyTile.appearIn(delay: Motion.stagger * 2)
                    boxesTile.appearIn(delay: Motion.stagger * 4)
                    fixTile.appearIn(delay: Motion.stagger * 6)
                }
            }
            Text("Today's Recommendation")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.leading, 4)
                .appearIn(delay: Motion.stagger * 7)
            recommendationCard.appearIn(delay: Motion.stagger * 8)
            if !inWindow { footer.appearIn(delay: Motion.stagger * 9) }
        }
        .padding(inWindow ? 0 : 14)
        .frame(width: width)
        .frame(maxWidth: width == nil ? 760 : nil)
        .fontDesign(.rounded)
        .animation(Motion.spring, value: model.settings.welcomeDone)
        .onAppear {
            model.reloadVault()
            if reduce { grown = true } else { withAnimation(Motion.spring.delay(0.35)) { grown = true } }
        }
    }

    // MARK: Header

    private var healthColor: Color {
        switch model.health {
        case .good: return Theme.good
        case .fair: return Theme.warn
        case .needsPractice: return Theme.bad
        case .gettingStarted: return Theme.link
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                (Text("English Health: ").foregroundStyle(.primary) + Text(model.health.rawValue).foregroundStyle(healthColor))
                    .font(.system(size: 20, weight: .bold))
                Text("\(model.entries.count) words from your notes · \(model.weekCategories.reduce(0) { $0 + $1.count }) mistakes this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            FloatingAppIcon(size: 58)
                .shadow(color: Theme.blue.opacity(0.5), radius: 12, y: 4)
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    // MARK: Welcome

    /// Shown until dismissed: where Gloss lives and how to open it.
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Theme.link, Theme.violet], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gloss lives in your menu bar").font(.system(size: 14, weight: .bold))
                    (Text("Click the ") + Text(Image(systemName: "character.book.closed")) +
                     Text(" book icon near the top right of your screen (the number is how many cards are due), or press ") +
                     Text(router.openHotKeyLabel()).bold().foregroundColor(Theme.link) + Text(" from anywhere."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer()
                Button("Got It") { model.settings.welcomeDone = true }
                    .buttonStyle(GlassPillStyle(tint: Theme.accent, prominent: true, compact: true))
            }
        }
        .padding(12)
        .glassCard(radius: 18, tint: Theme.blue, strength: 0.12)
    }

    // MARK: Tiles

    private var dueTile: some View {
        let split = model.dueSplit
        return Tile(icon: "rectangle.stack.fill", title: "Due now",
                    subtitle: "\(split.new) new · \(split.review) to review",
                    subtitleColor: model.dueCount > 0 ? Theme.warn : .secondary,
                    actionTitle: model.dueCount > 0 ? "Start Quiz" : "Practise More", action: startQuiz) {
            RollingNumber(value: model.dueCount, font: .system(size: 30, weight: .bold),
                          color: model.dueCount > 0 ? .primary : .secondary, delay: 0.2)
        }
    }

    private var accuracyTile: some View {
        let week = model.weekAnswers
        let days = model.accuracy(days: 7)
        let pct = week.answered == 0 ? nil : Int((Double(week.correct) / Double(week.answered) * 100).rounded())
        return Tile(icon: "target", iconColors: [Theme.good, Theme.blue], title: "Accuracy",
                    subtitle: "\(week.answered) answers · 7 days",
                    actionTitle: "Stats", action: router.showStats) {
            HStack(alignment: .bottom, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    if let pct {
                        RollingNumber(value: pct, font: .system(size: 24, weight: .bold), color: Theme.good, delay: 0.25)
                        Text("%").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.good)
                    } else {
                        Text("—").font(.system(size: 24, weight: .bold)).foregroundStyle(.secondary)
                    }
                }
                .padding(.trailing, 4)
                ForEach(days) { d in
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(d.answered == 0
                                  ? AnyShapeStyle(Color.white.opacity(0.12))
                                  : AnyShapeStyle(LinearGradient(colors: [Theme.good, Theme.blue], startPoint: .top, endPoint: .bottom)))
                            .frame(width: 9, height: max(4, 26 * d.accuracy * (grown ? 1 : 0.05)))
                        Text(String(d.day.iso.suffix(2))).font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 38, alignment: .bottom)
        }
    }

    private var streakTile: some View {
        let s = model.streak
        return Tile(icon: "flame.fill", iconColors: [Theme.warn, Theme.bad], title: "Streak",
                    subtitle: "Best: \(s.best) day\(s.best == 1 ? "" : "s")") {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                RollingNumber(value: s.current, font: .system(size: 26, weight: .bold), delay: 0.3)
                Text(s.current == 1 ? "day in a row" : "days in a row").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var boxesTile: some View {
        let counts = model.boxCounts
        let maxCount = max(counts.max() ?? 1, 1)
        let labels = ["New", "1", "2", "3", "4", "5"]
        return Tile(icon: "square.stack.3d.up.fill", title: "Leitner boxes",
                    subtitle: "\(counts.dropFirst().reduce(0, +)) learning · \(counts[5]) in box 5") {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<counts.count, id: \.self) { i in
                    VStack(spacing: 2) {
                        Text("\(counts[i])").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                        Capsule()
                            .fill(LinearGradient(colors: i == 0 ? [Color.white.opacity(0.35), Color.white.opacity(0.18)] : [Theme.violet, Theme.accent],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 18, height: max(4, 30 * CGFloat(counts[i]) / CGFloat(maxCount) * (grown ? 1 : 0.05)))
                            .animation(Motion.spring.delay(Double(i) * 0.05), value: grown)
                        Text(labels[i]).font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mistakesTile: some View {
        let week = model.weekCategories
        let total = max(week.reduce(0) { $0 + $1.count }, 1)
        let top = week.filter { $0.count > 0 }.sorted { $0.count > $1.count }.prefix(3)
        return Tile(icon: "exclamationmark.bubble.fill", iconColors: [Theme.bad, Theme.violet], title: "Mistakes, 7 days") {
            if top.isEmpty {
                Text("None in the last 7 days.").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(top)) { c in
                        HStack {
                            Text("#").foregroundStyle(Theme.link).fontWeight(.bold)
                            Text(c.category).font(.callout)
                            Spacer()
                            Text("\(Int((Double(c.count) / Double(total) * 100).rounded()))%")
                                .font(.callout.weight(.semibold)).monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var fixTile: some View {
        Tile(icon: "wand.and.stars", iconColors: [Theme.link, Theme.violet], title: "Fix my English",
             subtitle: "Select text, press \(router.hotKeyLabel())",
             actionTitle: "Try It", action: router.fixEnglish) {
            HStack(spacing: 6) {
                ForEach(Array(Array(router.hotKeyLabel()).map(String.init).enumerated()), id: \.offset) { _, k in
                    Text(k)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(minWidth: 24, minHeight: 24)
                        .glass(RoundedRectangle(cornerRadius: 7, style: .continuous), strength: 0.08)
                }
            }
        }
    }

    // MARK: Recommendation

    private var recommendationCard: some View {
        let r = model.recommendation(fixShortcut: router.hotKeyLabel())
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.blue, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(45))
                        .scaleEffect(0.8)
                    Image(systemName: r.symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.title).font(.system(size: 15, weight: .bold))
                    Text(r.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer()
                Button(r.actionTitle) { run(r.action) }
                    .buttonStyle(GlassPillStyle(compact: false))
            }
        }
        .padding(14)
        .glassCard(radius: 20, strength: 0.03)
        .hoverLift(radius: 20)
    }

    private func run(_ action: Recommendation.Action) {
        switch action {
        case .quiz: startQuiz()
        case .practice:
            model.startPractice(.hardest)
            startQuiz()
        case .stats: router.showStats()
        case .fix: router.fixEnglish()
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button { router.showStats() } label: { Image(systemName: "chart.bar.fill") }
                .buttonStyle(GlassCircleStyle())
                .help("Stats")
            Button { router.showOverview() } label: { Image(systemName: "macwindow") }
                .buttonStyle(GlassCircleStyle())
                .help("Open the Gloss window")
            Spacer()
            Button { startQuiz() } label: {
                Text(model.dueCount > 0 ? "Start Quiz · \(model.dueCount)" : "Practise More")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            Spacer()
            Button { router.showSettings() } label: { Image(systemName: "gearshape.fill") }
                .buttonStyle(GlassCircleStyle())
                .help("Settings")
            Button { router.quit() } label: { Image(systemName: "power") }
                .buttonStyle(GlassCircleStyle())
                .help("Quit Gloss")
        }
        .padding(.top, 4)
        .glassGroup(spacing: 8)
    }
}
