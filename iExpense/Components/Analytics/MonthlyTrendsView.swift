//
//  MonthlyTrendsView.swift
//  iExpense
//

import SwiftUI
import Charts

extension MonthlyTrend: Identifiable {
    public var id: String { "\(month)-\(year)" }
}

struct MonthlyTrendsView: View {
    let monthlyTrends: [MonthlyTrend]

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Monthly Spending")

                if monthlyTrends.isEmpty {
                    Text("Not enough history yet")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, InpensoTheme.Space.xl)
                } else {
                    Chart {
                        ForEach(monthlyTrends) { trend in
                            LineMark(
                                x: .value("Month", trend.shortMonthName),
                                y: .value("Amount", trend.amount)
                            )
                            .foregroundStyle(InpensoTheme.tide)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .symbol {
                                Circle()
                                    .fill(InpensoTheme.tide)
                                    .frame(width: 6, height: 6)
                            }
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(InpensoTheme.hairline)
                            AxisValueLabel()
                                .font(InpensoTheme.label(10))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                    }
                    .allowsHitTesting(false)

                    if let changeLabel = percentChangeLabel {
                        HStack(spacing: InpensoTheme.Space.xs) {
                            Image(systemName: changeLabel.isIncrease ? "arrow.up.right" : "arrow.down.right")
                                .font(InpensoTheme.label(11, weight: .bold))
                                .foregroundStyle(changeLabel.isIncrease ? InpensoTheme.danger : InpensoTheme.surplus)
                            Text(changeLabel.text)
                                .font(InpensoTheme.label(11))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                    }
                }
            }
        }
    }

    private var percentChangeLabel: (text: String, isIncrease: Bool)? {
        guard let first = monthlyTrends.first,
              let last = monthlyTrends.last,
              first.amount > 0, last.amount > 0 else { return nil }
        let percentChange = ((last.amount - first.amount) / first.amount) * 100
        let text = "\(abs(Int(percentChange)))% \(percentChange >= 0 ? "increase" : "decrease") over \(monthlyTrends.count) months"
        return (text, percentChange >= 0)
    }
}

struct CategoryTrendsView: View {
    struct CategoryTrend: Identifiable {
        var id: String { "\(categoryID)-\(month)-\(year)" }
        let categoryID: String
        let month: Int
        let year: Int
        let currentAmount: Double
        let previousAmount: Double
        var percentChange: Double {
            if previousAmount == 0 { return 0 }
            return ((currentAmount - previousAmount) / previousAmount) * 100
        }
        var isIncreasing: Bool {
            currentAmount > previousAmount
        }
    }

    @EnvironmentObject private var categoryStore: CategoryStore

    let categoryTrends: [CategoryTrend]
    let currencyCode: String

    init(
        categoryTrends: [CategoryTrend],
        currencyCode: String? = nil
    ) {
        self.categoryTrends = categoryTrends
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }

    private var topTrends: [CategoryTrend] {
        Array(
            categoryTrends
                .filter { $0.previousAmount > 0 }
                .sorted { abs($0.percentChange) > abs($1.percentChange) }
                .prefix(4)
        )
    }

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Category Changes")

                if topTrends.isEmpty {
                    Text("No comparison data available")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, InpensoTheme.Space.xl)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(topTrends.enumerated()), id: \.element.id) { index, trend in
                            categoryTrendRow(trend: trend)
                            if index < topTrends.count - 1 {
                                Divider().overlay(InpensoTheme.hairline)
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryTrendRow(trend: CategoryTrend) -> some View {
        let category = categoryStore.category(for: trend.categoryID)
        let trendColor = trend.isIncreasing ? InpensoTheme.danger : InpensoTheme.surplus

        return HStack(spacing: InpensoTheme.Space.sm) {
            Circle()
                .fill(category.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(InpensoTheme.body(14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Text("was \(trend.previousAmount, format: .currency(code: currencyCode))")
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(trend.currentAmount, format: .currency(code: currencyCode))
                    .font(InpensoTheme.label(13, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                HStack(spacing: 2) {
                    Image(systemName: trend.isIncreasing ? "arrow.up" : "arrow.down")
                        .font(InpensoTheme.label(10, weight: .bold))
                    Text("\(Int(abs(trend.percentChange)))%")
                        .font(InpensoTheme.label(11, weight: .bold))
                }
                .foregroundStyle(trendColor)
            }
        }
        .padding(.vertical, InpensoTheme.Space.sm)
    }
}

struct ProjectionView: View {
    let projectedMonthlySpend: Double
    let currentBudget: Double
    let currencyCode: String

    init(
        projectedMonthlySpend: Double,
        currentBudget: Double,
        currencyCode: String? = nil
    ) {
        self.projectedMonthlySpend = projectedMonthlySpend
        self.currentBudget = currentBudget
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Monthly Projection")

                HStack(spacing: 0) {
                    metricColumn(title: "Projected", value: projectedMonthlySpend, color: InpensoTheme.ink)

                    if currentBudget > 0 {
                        verticalRule
                        metricColumn(title: "Budget", value: currentBudget, color: InpensoTheme.ink)
                        verticalRule
                        let difference = projectedMonthlySpend - currentBudget
                        metricColumn(
                            title: "Difference",
                            value: abs(difference),
                            color: difference > 0 ? InpensoTheme.danger : InpensoTheme.surplus
                        )
                    }
                }

                if currentBudget > 0 {
                    let isOverBudget = projectedMonthlySpend > currentBudget
                    Text(isOverBudget
                         ? "Projected to exceed budget"
                         : "Projected to stay under budget")
                        .font(InpensoTheme.label(12, weight: .semibold))
                        .foregroundStyle(isOverBudget ? InpensoTheme.danger : InpensoTheme.surplus)
                }
            }
        }
    }

    private var verticalRule: some View {
        Rectangle()
            .fill(InpensoTheme.hairline)
            .frame(width: 1)
            .padding(.horizontal, InpensoTheme.Space.sm)
    }

    private func metricColumn(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xxs) {
            Text(title.uppercased())
                .font(InpensoTheme.label(10, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
            Text(value, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(18))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: InpensoTheme.Space.lg) {
        MonthlyTrendsView(monthlyTrends: (1...6).map { month in
            MonthlyTrend(month: month, year: 2025, amount: Double.random(in: 1500...3000))
        })

        CategoryTrendsView(categoryTrends: [
            CategoryTrendsView.CategoryTrend(
                categoryID: Category.food.categoryID,
                month: 5, year: 2025,
                currentAmount: 450.50, previousAmount: 380.25
            )
        ])
        .environmentObject(CategoryStore())

        ProjectionView(projectedMonthlySpend: 2850.50, currentBudget: 3000.00)
    }
    .padding(InpensoTheme.Space.screen)
    .background(InpensoTheme.foam)
}
