//
//  DailySpendingChartView.swift
//  iExpense
//

import SwiftUI
import Charts

struct DailySpendingChartView: View {
    struct DailySpending: Identifiable {
        var id: Int { dayOfMonth }
        let date: Date
        let dayOfMonth: Int
        let amount: Double
    }

    let dailySpending: [DailySpending]
    let averageDailySpend: Double

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Daily Spending")

                if dailySpending.isEmpty {
                    emptyState
                } else {
                    Chart {
                        ForEach(dailySpending) { daily in
                            BarMark(
                                x: .value("Day", daily.dayOfMonth),
                                y: .value("Amount", daily.amount)
                            )
                            .foregroundStyle(InpensoTheme.tide)
                            .cornerRadius(2)
                        }

                        if averageDailySpend > 0 {
                            RuleMark(y: .value("Average", averageDailySpend))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(InpensoTheme.surplus)
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Avg")
                                        .font(InpensoTheme.label(10, weight: .semibold))
                                        .foregroundStyle(InpensoTheme.surplus)
                                }
                        }
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 5)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(InpensoTheme.hairline)
                            AxisValueLabel()
                                .font(InpensoTheme.label(10))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(InpensoTheme.hairline)
                            AxisValueLabel()
                                .font(InpensoTheme.label(10))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                    }

                    if averageDailySpend > 0 {
                        HStack(spacing: InpensoTheme.Space.xs) {
                            Rectangle()
                                .fill(InpensoTheme.surplus)
                                .frame(width: 16, height: 1)
                            Text("Daily average: \(averageDailySpend, format: .currency(code: SettingsViewModel.getAppCurrency()))")
                                .font(InpensoTheme.label(11))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Text("No spending data for this period")
            .font(InpensoTheme.body(14))
            .foregroundStyle(InpensoTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, InpensoTheme.Space.xl)
    }
}

#Preview {
    let sampleData = (1...28).map { day in
        DailySpendingChartView.DailySpending(
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: day)) ?? Date(),
            dayOfMonth: day,
            amount: Double.random(in: 0...100)
        )
    }

    DailySpendingChartView(
        dailySpending: sampleData,
        averageDailySpend: sampleData.reduce(0) { $0 + $1.amount } / Double(sampleData.count)
    )
    .padding(InpensoTheme.Space.screen)
    .background(InpensoTheme.foam)
}
