//
//  AnalyticsView.swift
//  iExpense
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var pro: ProEntitlementManager
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel

    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    @State private var selectedTab: AnalyticsTab = .overview
    @State private var showSaveBudgetSuccess: Bool = false

    @State private var selectedMonth: Int
    @State private var selectedYear: Int

    init(analyticsViewModel: AnalyticsViewModel) {
        self.analyticsViewModel = analyticsViewModel
        _selectedMonth = State(initialValue: analyticsViewModel.selectedMonth)
        _selectedYear = State(initialValue: analyticsViewModel.selectedYear)
    }

    private var currencyCode: String {
        settingsViewModel.selectedCurrency
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            VStack(spacing: InpensoTheme.Space.md) {
                MonthYearPicker(
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear,
                    onMonthYearChanged: {
                        analyticsViewModel.selectedMonth = selectedMonth
                        analyticsViewModel.selectedYear = selectedYear
                        analyticsViewModel.calculateAnalytics()
                    }
                )
                .inpensoScreenPadding()

                AnalyticsTabSelector(selectedTab: $selectedTab)
                    .inpensoScreenPadding()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: InpensoTheme.Space.section) {
                        switch selectedTab {
                        case .overview: overviewTabContent
                        case .trends:
                            if pro.canUseFullInsights {
                                trendsTabContent
                            } else {
                                insightsLockedCard
                            }
                        case .insights:
                            if pro.canUseFullInsights {
                                insightsTabContent
                            } else {
                                insightsLockedCard
                            }
                        case .budget: budgetTabContent
                        }
                    }
                    .inpensoScreenPadding()
                    .padding(.bottom, InpensoTheme.Space.bottomClearance)
                }
            }
            .padding(.top, InpensoTheme.Space.sm)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Budget Saved", isPresented: $showSaveBudgetSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your monthly budget has been saved successfully.")
        }
        .onAppear {
            OnboardingStore.shared.ensureInsightsPreviewStarted()
        }
    }

    private var insightsLockedCard: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                Text("Deeper Insights")
                    .font(InpensoTheme.body(17, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                Text("Trends and pattern cards unlock with Pro, or during your 14-day preview.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                Button("Upgrade to Pro") {
                    pro.openPaywall(plan: .yearly)
                }
                .buttonStyle(InpensoPrimaryButtonStyle())
            }
        }
    }

    // MARK: - Overview

    private var overviewTabContent: some View {
        VStack(spacing: InpensoTheme.Space.section) {
            if !ProEntitlementManager.shared.isPro,
               OnboardingStore.shared.insightsPreviewActive {
                Text("Insights preview · \(OnboardingStore.shared.insightsPreviewDaysRemaining) days left")
                    .font(InpensoTheme.label(12, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            summaryCardsGrid

            DailySpendingChartView(
                dailySpending: analyticsViewModel.dailySpending.map { spending in
                    DailySpendingChartView.DailySpending(
                        date: spending.date,
                        dayOfMonth: spending.dayOfMonth,
                        amount: spending.amount
                    )
                },
                averageDailySpend: analyticsViewModel.averageDailySpend
            )

            SpendingHeatmapView(
                dailyAmounts: heatmapAmounts,
                currencyCode: currencyCode
            )

            CategoryBreakdownView(
                spendingByCategory: analyticsViewModel.spendingByCategory,
                totalSpent: analyticsViewModel.totalSpent,
                currencyCode: currencyCode
            )
        }
    }

    private var heatmapAmounts: [Date: Double] {
        let calendar = Calendar.current
        var map: [Date: Double] = [:]
        for expense in expenseViewModel.expenses where expense.type == .expense && !expense.isBalanceAdjustment {
            let day = calendar.startOfDay(for: expense.date)
            map[day, default: 0] += expense.homeAmount
        }
        return map
    }

    private var summaryCardsGrid: some View {
        SummaryCardGrid(summaryCards: [
            SummaryCard(
                title: "Total Spent",
                value: analyticsViewModel.totalSpent,
                valueFormat: .currency,
                icon: "dollarsign.circle.fill",
                color: InpensoTheme.tide,
                currencyCode: currencyCode
            ),
            SummaryCard(
                title: "Income",
                value: analyticsViewModel.totalIncome,
                valueFormat: .currency,
                icon: "arrow.down.circle.fill",
                color: InpensoTheme.surplus,
                currencyCode: currencyCode
            ),
            SummaryCard(
                title: "Net",
                value: analyticsViewModel.netCashflow,
                valueFormat: .currency,
                icon: "equal.circle.fill",
                color: analyticsViewModel.netCashflow >= 0 ? InpensoTheme.surplus : InpensoTheme.danger,
                currencyCode: currencyCode
            ),
            SummaryCard(
                title: "Daily Average",
                value: analyticsViewModel.averageDailySpend,
                valueFormat: .currency,
                icon: "calendar.badge.clock",
                color: InpensoTheme.slate,
                currencyCode: currencyCode
            ),
            analyticsViewModel.currentBudget > 0 ?
                SummaryCard(
                    title: "Budget Used",
                    value: min(100, (analyticsViewModel.totalSpent / analyticsViewModel.currentBudget) * 100),
                    valueFormat: .percent,
                    icon: "chart.pie.fill",
                    color: min(100, (analyticsViewModel.totalSpent / analyticsViewModel.currentBudget) * 100) >= 90 ? InpensoTheme.danger :
                          (min(100, (analyticsViewModel.totalSpent / analyticsViewModel.currentBudget) * 100) >= 75 ? InpensoTheme.copperSoft : InpensoTheme.tide),
                    currencyCode: currencyCode
                ) :
                SummaryCard(
                    title: "Budget",
                    value: 0,
                    valueFormat: .noBudget,
                    icon: "chart.pie.fill",
                    color: InpensoTheme.muted,
                    currencyCode: currencyCode
                ),
            analyticsViewModel.currentBudget > 0 && analyticsViewModel.daysRemainingInMonth > 0 ?
                SummaryCard(
                    title: "Per Day Left",
                    value: analyticsViewModel.budgetRemainingPerDay,
                    valueFormat: .currency,
                    icon: "calendar.badge.clock",
                    color: InpensoTheme.tide,
                    currencyCode: currencyCode
                ) :
                SummaryCard(
                    title: "Days Left",
                    value: Double(analyticsViewModel.daysRemainingInMonth),
                    valueFormat: .days,
                    icon: "calendar",
                    color: InpensoTheme.slate,
                    currencyCode: currencyCode
                )
        ])
    }

    // MARK: - Trends

    private var trendsTabContent: some View {
        VStack(spacing: InpensoTheme.Space.section) {
            MonthlyTrendsView(monthlyTrends: analyticsViewModel.monthlyTrends)

            CategoryTrendsView(
                categoryTrends: analyticsViewModel.categoryTrends.map { trend in
                    CategoryTrendsView.CategoryTrend(
                        categoryID: trend.categoryID,
                        month: analyticsViewModel.selectedMonth,
                        year: analyticsViewModel.selectedYear,
                        currentAmount: trend.currentAmount,
                        previousAmount: trend.previousAmount
                    )
                },
                currencyCode: currencyCode
            )

            if analyticsViewModel.projectedMonthlySpend > 0 {
                ProjectionView(
                    projectedMonthlySpend: analyticsViewModel.projectedMonthlySpend,
                    currentBudget: analyticsViewModel.currentBudget,
                    currencyCode: currencyCode
                )
            }
        }
    }

    // MARK: - Insights

    private var insightsTabContent: some View {
        VStack(spacing: InpensoTheme.Space.section) {
            KeyStatisticsView(
                biggestExpenseCategory: analyticsViewModel.biggestExpenseCategory,
                totalSpent: analyticsViewModel.totalSpent,
                mostActiveSpendingPeriod: findMostActiveSpendingPeriod(),
                currencyCode: currencyCode
            )

            InsightsCardView(insights: analyticsViewModel.insights)

            SpendingPatternView(
                weekdayVsWeekendAnalysis: analyzeWeekdayVsWeekend(),
                monthlyPatternAnalysis: analyzeMonthlyPattern()
            )
        }
    }

    private func findMostActiveSpendingPeriod() -> String? {
        let dailySpending = analyticsViewModel.dailySpending
        let daysWithExpenses = dailySpending.filter { $0.amount > 0 }
        if daysWithExpenses.isEmpty { return nil }

        let weekdayGroups = Dictionary(grouping: daysWithExpenses) { day in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE"
            return dateFormatter.string(from: day.date)
        }

        let weekdayAverages = weekdayGroups.mapValues { days in
            days.reduce(0) { $0 + $1.amount } / Double(days.count)
        }

        if let topWeekday = weekdayAverages.max(by: { $0.value < $1.value }) {
            return topWeekday.key
        }
        return nil
    }

    private func analyzeWeekdayVsWeekend() -> SpendingPatternView.PatternAnalysis? {
        let dailySpending = analyticsViewModel.dailySpending
        if dailySpending.isEmpty { return nil }

        var weekdaySpending: [Double] = []
        var weekendSpending: [Double] = []

        for day in dailySpending {
            let weekday = Calendar.current.component(.weekday, from: day.date)
            if weekday == 1 || weekday == 7 {
                weekendSpending.append(day.amount)
            } else {
                weekdaySpending.append(day.amount)
            }
        }

        let weekdayAvg = weekdaySpending.reduce(0, +) / Double(max(1, weekdaySpending.count))
        let weekendAvg = weekendSpending.reduce(0, +) / Double(max(1, weekendSpending.count))
        let ratio = weekdayAvg > 0 ? weekendAvg / weekdayAvg : 0

        if ratio > 1.5 {
            return SpendingPatternView.PatternAnalysis(
                title: "Weekend Spender",
                description: "You spend \(Int(ratio * 100))% more on weekends compared to weekdays",
                icon: "party.popper",
                color: InpensoTheme.copperSoft
            )
        } else if ratio > 1.1 {
            return SpendingPatternView.PatternAnalysis(
                title: "Slightly Higher Weekend Spending",
                description: "Your weekend spending is moderately higher than weekdays",
                icon: "calendar.badge.plus",
                color: InpensoTheme.tide
            )
        } else if ratio < 0.7 {
            return SpendingPatternView.PatternAnalysis(
                title: "Weekday Focused",
                description: "You spend significantly more on weekdays than weekends",
                icon: "briefcase",
                color: InpensoTheme.slate
            )
        } else {
            return SpendingPatternView.PatternAnalysis(
                title: "Balanced Spending",
                description: "Your spending is fairly consistent throughout the week",
                icon: "equal.circle",
                color: InpensoTheme.surplus
            )
        }
    }

    private func analyzeMonthlyPattern() -> SpendingPatternView.PatternAnalysis? {
        let dailySpending = analyticsViewModel.dailySpending
        if dailySpending.isEmpty { return nil }

        var earlyMonthSpending: [Double] = []
        var midMonthSpending: [Double] = []
        var lateMonthSpending: [Double] = []

        for day in dailySpending {
            if day.dayOfMonth <= 10 {
                earlyMonthSpending.append(day.amount)
            } else if day.dayOfMonth <= 20 {
                midMonthSpending.append(day.amount)
            } else {
                lateMonthSpending.append(day.amount)
            }
        }

        let earlyAvg = earlyMonthSpending.reduce(0, +) / Double(max(1, earlyMonthSpending.count))
        let midAvg = midMonthSpending.reduce(0, +) / Double(max(1, midMonthSpending.count))
        let lateAvg = lateMonthSpending.reduce(0, +) / Double(max(1, lateMonthSpending.count))
        let maxAvg = max(earlyAvg, max(midAvg, lateAvg))

        if maxAvg == earlyAvg && earlyAvg > midAvg * 1.3 && earlyAvg > lateAvg * 1.3 {
            return SpendingPatternView.PatternAnalysis(
                title: "Early Month Spender",
                description: "You tend to spend more in the first part of the month",
                icon: "calendar.badge.plus",
                color: InpensoTheme.surplus
            )
        } else if maxAvg == lateAvg && lateAvg > earlyAvg * 1.3 && lateAvg > midAvg * 1.3 {
            return SpendingPatternView.PatternAnalysis(
                title: "End of Month Spender",
                description: "Your spending increases toward the end of the month",
                icon: "calendar.badge.exclamationmark",
                color: InpensoTheme.danger
            )
        } else if maxAvg == midAvg && midAvg > earlyAvg * 1.3 && midAvg > lateAvg * 1.3 {
            return SpendingPatternView.PatternAnalysis(
                title: "Mid-Month Spike",
                description: "Your spending peaks in the middle of the month",
                icon: "waveform.path.ecg",
                color: InpensoTheme.copperSoft
            )
        } else {
            return SpendingPatternView.PatternAnalysis(
                title: "Consistent Throughout Month",
                description: "Your spending is fairly evenly distributed throughout the month",
                icon: "equal.circle",
                color: InpensoTheme.tide
            )
        }
    }

    // MARK: - Budget

    private var budgetTabContent: some View {
        VStack(spacing: InpensoTheme.Space.section) {
            BudgetInputView(
                currentBudget: $analyticsViewModel.currentBudget,
                currencyCode: currencyCode,
                onSave: saveBudget
            )

            if analyticsViewModel.currentBudget > 0 {
                BudgetStatusView(
                    totalSpent: analyticsViewModel.totalSpent,
                    currentBudget: analyticsViewModel.currentBudget,
                    daysRemainingInMonth: analyticsViewModel.daysRemainingInMonth,
                    budgetRemainingPerDay: analyticsViewModel.budgetRemainingPerDay,
                    currencyCode: currencyCode
                )

                BudgetRecommendationsView(
                    biggestExpenseCategory: analyticsViewModel.biggestExpenseCategory,
                    totalSpent: analyticsViewModel.totalSpent,
                    currentBudget: analyticsViewModel.currentBudget,
                    daysRemainingInMonth: analyticsViewModel.daysRemainingInMonth,
                    suggestedBudget: calculateSuggestedBudget(),
                    currencyCode: currencyCode
                )
            }

            CategoryBudgetsView(analyticsViewModel: analyticsViewModel)

            BudgetHistoryView(complianceData: createBudgetComplianceData())
        }
    }

    private func calculateSuggestedBudget() -> Double {
        if analyticsViewModel.monthlyTrends.count >= 3 {
            let recentMonths = Array(analyticsViewModel.monthlyTrends.suffix(3))
            let avgSpending = recentMonths.reduce(0) { $0 + $1.amount } / Double(recentMonths.count)
            return ceil(avgSpending * 1.1 / 10) * 10
        }
        if analyticsViewModel.projectedMonthlySpend > 0 {
            return ceil(analyticsViewModel.projectedMonthlySpend * 1.05 / 10) * 10
        }
        return 0
    }

    private func createBudgetComplianceData() -> [BudgetHistoryView.BudgetComplianceData] {
        var result: [BudgetHistoryView.BudgetComplianceData] = []

        for trend in analyticsViewModel.monthlyTrends.dropLast() {
            let key = analyticsViewModel.budgetKey(forMonth: trend.month, year: trend.year)
            if let budget = analyticsViewModel.monthlyBudgets[key], budget > 0 {
                let compliancePercent = (trend.amount / budget) * 100
                let color: Color = compliancePercent <= 90 ? InpensoTheme.surplus :
                                    (compliancePercent <= 100 ? InpensoTheme.tide :
                                    (compliancePercent <= 110 ? InpensoTheme.copperSoft : InpensoTheme.danger))

                result.append(BudgetHistoryView.BudgetComplianceData(
                    month: trend.month,
                    year: trend.year,
                    monthName: trend.shortMonthName,
                    compliancePercent: compliancePercent,
                    color: color
                ))
            }
        }
        return result
    }

    private func saveBudget() {
        let key = analyticsViewModel.budgetKey(forMonth: analyticsViewModel.selectedMonth, year: analyticsViewModel.selectedYear)
        analyticsViewModel.monthlyBudgets[key] = analyticsViewModel.currentBudget
        StorageService.saveBudgets(analyticsViewModel.monthlyBudgets)
        showSaveBudgetSuccess = true
        HapticFeedback.success()
    }
}

#Preview {
    AnalyticsView(analyticsViewModel: AnalyticsViewModel(expenses: []))
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
