//
//  SpendingHeatmapView.swift
//  iExpense
//

import SwiftUI

struct SpendingHeatmapView: View {
    let dailyAmounts: [Date: Double]
    var currencyCode: String

    private let calendar = Calendar.current
    private let weeksToShow = 12

    private var maxAmount: Double {
        max(dailyAmounts.values.max() ?? 0, 1)
    }

    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(weeksToShow * 7 - 1), to: today) else { return [] }
        var result: [Date] = []
        var cursor = start
        while cursor <= today {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private var columns: [[Date]] {
        stride(from: 0, to: days.count, by: 7).map { index in
            Array(days[index..<min(index + 7, days.count)])
        }
    }

    var body: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                Text("Spending heatmap")
                    .font(InpensoTheme.body(16, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Text("Last \(weeksToShow) weeks · darker = higher spend")
                    .font(InpensoTheme.label(12))
                    .foregroundStyle(InpensoTheme.muted)

                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 4) {
                            ForEach(week, id: \.self) { day in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(color(for: day))
                                    .frame(width: 12, height: 12)
                                    .accessibilityLabel(accessibility(for: day))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func color(for day: Date) -> Color {
        let amount = dailyAmounts[calendar.startOfDay(for: day)] ?? 0
        if amount <= 0 { return InpensoTheme.mist }
        let intensity = min(1, amount / maxAmount)
        return InpensoTheme.tide.opacity(0.2 + 0.8 * intensity)
    }

    private func accessibility(for day: Date) -> String {
        let amount = dailyAmounts[calendar.startOfDay(for: day)] ?? 0
        return "\(day.formatted(date: .abbreviated, time: .omitted)): \(amount.formatted(.currency(code: currencyCode)))"
    }
}
