import Charts
import GlossCore
import SwiftUI

/// Mistakes per category (7 and 30 days), the most repeated spelling words, and quiz accuracy per day.
struct StatsView: View {
    @EnvironmentObject var model: AppModel

    /// Days shown in the accuracy chart. See MECHANICS.md.
    static let accuracyDays = 14

    private struct Row: Identifiable {
        var category: String
        var period: String
        var count: Int
        var id: String { category + period }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                categorySection
                HStack(alignment: .top, spacing: 20) {
                    topWordsSection.frame(maxWidth: .infinity, alignment: .topLeading)
                    accuracySection.frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 720, minHeight: 600)
        .onAppear { model.reloadVault() }
    }

    private var rows: [Row] {
        let week = model.categoryCounts(days: 7)
        let month = model.categoryCounts(days: 30)
        return week.map { Row(category: $0.category, period: "Last 7 days", count: $0.count) }
            + month.map { Row(category: $0.category, period: "Last 30 days", count: $0.count) }
    }

    private var categorySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Chart(rows) { r in
                    BarMark(x: .value("Category", r.category), y: .value("Mistakes", r.count))
                        .foregroundStyle(by: .value("Period", r.period))
                        .position(by: .value("Period", r.period))
                        .annotation(position: .top) {
                            if r.count > 0 { Text("\(r.count)").font(.caption2).foregroundStyle(.secondary) }
                        }
                }
                .chartForegroundStyleScale(["Last 7 days": Color.orange, "Last 30 days": Color.blue])
                .frame(height: 220)
                Text("\(model.snapshot.mistakes.count) mistake lines read from 錯誤紀錄/")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } label: {
            Label("Mistakes per category", systemImage: "chart.bar.xaxis")
        }
    }

    private var topWordsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                let top = model.topRepeated
                if top.isEmpty { Text("No spelling words yet.").foregroundStyle(.secondary) }
                let maxCount = max(top.first?.count ?? 1, 1)
                ForEach(Array(top.enumerated()), id: \.offset) { i, e in
                    HStack(spacing: 8) {
                        Text("\(i + 1).").font(.caption).foregroundStyle(.secondary).frame(width: 22, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.word).font(.system(.body, design: .monospaced))
                            Text(e.meaning).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red.opacity(0.7))
                            .frame(width: CGFloat(e.count) / CGFloat(maxCount) * 60, height: 8)
                        Text("\(e.count)×").font(.caption.monospacedDigit()).frame(width: 30, alignment: .trailing)
                    }
                }
            }
        } label: {
            Label("Top 10 repeated spelling words", systemImage: "repeat")
        }
    }

    private var accuracySection: some View {
        GroupBox {
            let days = model.accuracy(days: Self.accuracyDays)
            VStack(alignment: .leading, spacing: 8) {
                Chart(days) { d in
                    BarMark(x: .value("Day", String(d.day.iso.suffix(5))), y: .value("Accuracy", d.accuracy * 100))
                        .foregroundStyle(d.answered == 0 ? Color.secondary.opacity(0.3) : Color.green)
                        .annotation(position: .top) {
                            if d.answered > 0 { Text("\(d.answered)").font(.caption2).foregroundStyle(.secondary) }
                        }
                }
                .chartYScale(domain: 0...100)
                .chartYAxisLabel("% right")
                .frame(height: 220)
                let total = days.reduce(0) { $0 + $1.answered }
                let right = days.reduce(0) { $0 + $1.correct }
                Text(total == 0 ? "No answers yet." :
                        "\(right) of \(total) right in \(Self.accuracyDays) days (\(Int((Double(right) / Double(total) * 100).rounded()))%). Numbers above bars are answers.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } label: {
            Label("Quiz accuracy per day", systemImage: "checkmark.circle")
        }
    }
}
