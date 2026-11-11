import Charts
import GlossCore
import SwiftUI

/// A titled glass card.
struct GlassSection<Content: View>: View {
    let title: String
    let icon: String
    var tint: Color = Theme.accent
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .glass(Circle(), tint: tint, strength: 0.85)
                Text(title).font(.headline)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard(radius: 30, strength: 0.03)
    }
}

/// Mistakes per category (7 and 30 days), the most repeated spelling words, and quiz accuracy per day.
struct StatsView: View {
    @EnvironmentObject var model: AppModel

    /// Days shown in the accuracy chart. See MECHANICS.md.
    static let accuracyDays = 14

    /// Chart bars grow from zero when the page appears.
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    private struct Row: Identifiable {
        var category: String
        var period: String
        var count: Int
        var id: String { category + period }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Your English").font(.system(size: 26, weight: .bold))
                    Spacer()
                    Text("\(model.dueCount) due now")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .glass(Capsule(), tint: Theme.bad, strength: model.dueCount > 0 ? 0.25 : 0.05)
                }
                categorySection.appearIn(delay: 0.05)
                HStack(alignment: .top, spacing: 16) {
                    topWordsSection.appearIn(delay: 0.15)
                    accuracySection.appearIn(delay: 0.25)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 34)
            .padding(.bottom, 22)
            .glassGroup(spacing: 16)
        }
        .fontDesign(.rounded)
        .frame(minWidth: 640, minHeight: 560)
        .onAppear {
            model.reloadVault()
            if reduce { grown = true } else { withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3).scaled) { grown = true } }
        }
    }

    private var rows: [Row] {
        let week = model.categoryCounts(days: 7)
        let month = model.categoryCounts(days: 30)
        return week.map { Row(category: $0.category, period: "Last 7 days", count: $0.count) }
            + month.map { Row(category: $0.category, period: "Last 30 days", count: $0.count) }
    }

    private var categorySection: some View {
        GlassSection(title: "Mistakes per category", icon: "chart.bar.xaxis", tint: Theme.violet) {
            Chart(rows) { r in
                BarMark(x: .value("Category", r.category), y: .value("Mistakes", grown ? r.count : 0))
                    .foregroundStyle(by: .value("Period", r.period))
                    .position(by: .value("Period", r.period))
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        if r.count > 0 { Text("\(r.count)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary) }
                    }
            }
            .chartForegroundStyleScale([
                "Last 7 days": LinearGradient(colors: [Theme.violet, Theme.bad], startPoint: .top, endPoint: .bottom),
                "Last 30 days": LinearGradient(colors: [Theme.blue, Theme.accent], startPoint: .top, endPoint: .bottom),
            ])
            .chartYScale(domain: 0...max(1, rows.map(\.count).max() ?? 1))
            .frame(height: 210)
            Text("\(model.snapshot.mistakes.count) mistake lines read from 錯誤紀錄/")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var topWordsSection: some View {
        GlassSection(title: "Top 10 repeated spelling words", icon: "repeat", tint: Theme.bad) {
            let top = model.topRepeated
            if top.isEmpty { Text("No spelling words yet.").foregroundStyle(.secondary) }
            let maxCount = max(top.first?.count ?? 1, 1)
            VStack(spacing: 6) {
                ForEach(Array(top.enumerated()), id: \.offset) { i, e in
                    HStack(spacing: 8) {
                        Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 18, alignment: .trailing)
                        SpeakerButton(text: e.word, size: 24)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(e.word).font(.system(.body, design: .monospaced).weight(.semibold))
                            Text(e.meaning).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.violet, Theme.bad], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, CGFloat(e.count) / CGFloat(maxCount) * 60 * (grown ? 1 : 0.1)), height: 7)
                            .animation(Motion.spring.delay(Double(i) * 0.04).scaled, value: grown)
                        Text("\(e.count)×").font(.caption.monospacedDigit().weight(.semibold)).frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var accuracySection: some View {
        GlassSection(title: "Quiz accuracy per day", icon: "checkmark", tint: Theme.good) {
            let days = model.accuracy(days: Self.accuracyDays)
            Chart(days) { d in
                BarMark(x: .value("Day", String(d.day.iso.suffix(2))), y: .value("Accuracy", grown ? d.accuracy * 100 : 0))
                    .foregroundStyle(d.answered == 0
                                     ? AnyShapeStyle(Color.secondary.opacity(0.25))
                                     : AnyShapeStyle(LinearGradient(colors: [Theme.good, Theme.blue], startPoint: .top, endPoint: .bottom)))
                    .cornerRadius(5)
                    .annotation(position: .top) {
                        if d.answered > 0 { Text("\(d.answered)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary) }
                    }
            }
            .chartYScale(domain: 0...100)
            .chartYAxisLabel("% right")
            .frame(height: 230)
            let total = days.reduce(0) { $0 + $1.answered }
            let right = days.reduce(0) { $0 + $1.correct }
            Text(total == 0 ? "No answers yet." :
                    "\(right) of \(total) right in \(Self.accuracyDays) days (\(Int((Double(right) / Double(total) * 100).rounded()))%). Numbers above bars are answers.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
