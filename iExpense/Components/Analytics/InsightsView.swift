//
//  InsightsView.swift
//  iExpense
//

import SwiftUI

extension SpendingInsight: Identifiable {
    public var id: String { title }
}

struct KeyStatisticsView: View {
    @EnvironmentObject private var categoryStore: CategoryStore

    let biggestExpenseCategory: (categoryID: String, amount: Double)?
    let totalSpent: Double
    let mostActiveSpendingPeriod: String?
    let currencyCode: String

    init(
        biggestExpenseCategory: (categoryID: String, amount: Double)?,
        totalSpent: Double,
        mostActiveSpendingPeriod: String?,
        currencyCode: String? = nil
    ) {
        self.biggestExpenseCategory = biggestExpenseCategory
        self.totalSpent = totalSpent
        self.mostActiveSpendingPeriod = mostActiveSpendingPeriod
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Key Statistics")

                if biggestExpenseCategory == nil && mostActiveSpendingPeriod == nil {
                    Text("Not enough data yet")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, InpensoTheme.Space.md)
                } else {
                    VStack(spacing: 0) {
                        if let (categoryID, amount) = biggestExpenseCategory {
                            topCategoryRow(categoryID: categoryID, amount: amount)
                            if mostActiveSpendingPeriod != nil {
                                Divider().overlay(InpensoTheme.hairline)
                            }
                        }
                        if let period = mostActiveSpendingPeriod {
                            activeDayRow(period: period)
                        }
                    }
                }
            }
        }
    }

    private func topCategoryRow(categoryID: String, amount: Double) -> some View {
        let category = categoryStore.category(for: categoryID)
        return HStack(spacing: InpensoTheme.Space.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Top category")
                    .font(InpensoTheme.label(11, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
                HStack(spacing: InpensoTheme.Space.xs) {
                    Circle().fill(category.color).frame(width: 8, height: 8)
                    Text(category.displayName)
                        .font(InpensoTheme.body(16, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(18))
                    .foregroundStyle(InpensoTheme.ink)
                if totalSpent > 0 {
                    Text("\(Int((amount / totalSpent) * 100))% of total")
                        .font(InpensoTheme.label(10))
                        .foregroundStyle(InpensoTheme.muted)
                }
            }
        }
        .padding(.vertical, InpensoTheme.Space.sm)
    }

    private func activeDayRow(period: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Most active day")
                    .font(InpensoTheme.label(11, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
                Text(period)
                    .font(InpensoTheme.body(16, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
            }
            Spacer()
        }
        .padding(.vertical, InpensoTheme.Space.sm)
    }
}

struct InsightsCardView: View {
    let insights: [SpendingInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Smart Insights")

            if insights.isEmpty {
                SurfacePanel(padding: InpensoTheme.Space.md) {
                    Text("Insights appear as you track more spending")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: InpensoTheme.Space.sm) {
                    ForEach(insights) { insight in
                        insightRow(insight: insight)
                    }
                }
            }
        }
    }

    private func insightRow(insight: SpendingInsight) -> some View {
        HStack(alignment: .top, spacing: InpensoTheme.Space.md) {
            Rectangle()
                .fill(insightThemeColor(for: insight))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: InpensoTheme.Space.xxs) {
                Text(insight.title)
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Text(insight.description)
                    .font(InpensoTheme.body(13))
                    .foregroundStyle(InpensoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(InpensoTheme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .stroke(InpensoTheme.hairline, lineWidth: 1)
                )
        )
    }

    private func insightThemeColor(for insight: SpendingInsight) -> Color {
        switch insight.type {
        case .positive: return InpensoTheme.surplus
        case .negative: return InpensoTheme.danger
        case .neutral: return InpensoTheme.tide
        }
    }
}

struct SpendingPatternView: View {
    struct PatternAnalysis {
        let title: String
        let description: String
        let icon: String
        let color: Color
    }

    let weekdayVsWeekendAnalysis: PatternAnalysis?
    let monthlyPatternAnalysis: PatternAnalysis?

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Spending Patterns")

                if weekdayVsWeekendAnalysis == nil && monthlyPatternAnalysis == nil {
                    Text("Not enough data")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, InpensoTheme.Space.md)
                } else {
                    VStack(spacing: 0) {
                        if let analysis = weekdayVsWeekendAnalysis {
                            patternRow(analysis: analysis, label: "Weekday vs weekend")
                            if monthlyPatternAnalysis != nil {
                                Divider().overlay(InpensoTheme.hairline)
                            }
                        }
                        if let analysis = monthlyPatternAnalysis {
                            patternRow(analysis: analysis, label: "Monthly rhythm")
                        }
                    }
                }
            }
        }
    }

    private func patternRow(analysis: PatternAnalysis, label: String) -> some View {
        HStack(alignment: .top, spacing: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(InpensoTheme.label(10, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
                Text(analysis.title)
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Text(analysis.description)
                    .font(InpensoTheme.body(13))
                    .foregroundStyle(InpensoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: InpensoTheme.Space.sm)
            Image(systemName: analysis.icon)
                .font(InpensoTheme.body(18))
                .foregroundStyle(analysis.color)
        }
        .padding(.vertical, InpensoTheme.Space.sm)
    }
}

#Preview {
    VStack(spacing: InpensoTheme.Space.lg) {
        KeyStatisticsView(
            biggestExpenseCategory: (Category.food.categoryID, 450.50),
            totalSpent: 1850.25,
            mostActiveSpendingPeriod: "Wednesday"
        )
        .environmentObject(CategoryStore())

        InsightsCardView(insights: [
            SpendingInsight(
                type: .positive,
                title: "Weekend Spending Trend",
                description: "You tend to spend 45% more on weekends compared to weekdays",
                icon: "calendar.badge.exclamationmark",
                color: InpensoTheme.copperSoft
            )
        ])

        SpendingPatternView(
            weekdayVsWeekendAnalysis: SpendingPatternView.PatternAnalysis(
                title: "Weekend Spender",
                description: "You spend 145% more on weekends compared to weekdays",
                icon: "party.popper",
                color: InpensoTheme.copperSoft
            ),
            monthlyPatternAnalysis: nil
        )
    }
    .padding(InpensoTheme.Space.screen)
    .background(InpensoTheme.foam)
}
