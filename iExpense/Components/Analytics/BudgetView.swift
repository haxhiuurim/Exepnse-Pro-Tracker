//
//  BudgetView.swift
//  iExpense
//

import SwiftUI
import Charts

struct BudgetInputView: View {
    @Binding var currentBudget: Double
    let currencyCode: String
    let onSave: () -> Void

    init(
        currentBudget: Binding<Double>,
        currencyCode: String? = nil,
        onSave: @escaping () -> Void
    ) {
        self._currentBudget = currentBudget
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
        self.onSave = onSave
    }

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Set Monthly Budget")

                VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
                    Text("Amount")
                        .font(InpensoTheme.label(11, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)

                    TextField("0", value: $currentBudget, format: .currency(code: currencyCode))
                        .keyboardType(.decimalPad)
                        .font(InpensoTheme.displayAmount(24))
                        .foregroundStyle(InpensoTheme.ink)
                        .padding(InpensoTheme.Space.md)
                        .background(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                                .fill(InpensoTheme.mist)
                        )
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { hideKeyboard() }
                                    .font(InpensoTheme.label(15, weight: .semibold))
                                    .foregroundStyle(InpensoTheme.copper)
                            }
                        }
                }

                Button(action: onSave) {
                    Text("Save Budget")
                }
                .buttonStyle(InpensoPrimaryButtonStyle(enabled: currentBudget > 0))
                .disabled(currentBudget <= 0)
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct BudgetStatusView: View {
    let totalSpent: Double
    let currentBudget: Double
    let daysRemainingInMonth: Int
    let budgetRemainingPerDay: Double
    let currencyCode: String

    init(
        totalSpent: Double,
        currentBudget: Double,
        daysRemainingInMonth: Int,
        budgetRemainingPerDay: Double,
        currencyCode: String? = nil
    ) {
        self.totalSpent = totalSpent
        self.currentBudget = currentBudget
        self.daysRemainingInMonth = daysRemainingInMonth
        self.budgetRemainingPerDay = budgetRemainingPerDay
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }

    private var progress: Double {
        min(1.0, totalSpent / currentBudget)
    }

    private var progressColor: Color {
        if progress >= 0.9 { return InpensoTheme.danger }
        if progress >= 0.75 { return InpensoTheme.copperSoft }
        return InpensoTheme.tide
    }

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Budget Status")

                VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
                    HStack {
                        Text("\(Int(progress * 100))% used")
                            .font(InpensoTheme.label(12, weight: .semibold))
                            .foregroundStyle(progressColor)
                        Spacer()
                        Text("\(Int((1 - progress) * 100))% left")
                            .font(InpensoTheme.label(12))
                            .foregroundStyle(InpensoTheme.muted)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(InpensoTheme.mist)
                            Capsule()
                                .fill(progressColor)
                                .frame(width: geometry.size.width * CGFloat(progress))
                        }
                    }
                    .frame(height: 8)
                }

                HStack(spacing: 0) {
                    budgetMetric(title: "Spent", value: totalSpent, alignment: .leading)
                    Spacer()
                    budgetMetric(
                        title: "Remaining",
                        value: max(0, currentBudget - totalSpent),
                        alignment: .trailing
                    )
                }

                if daysRemainingInMonth > 0 {
                    Divider().overlay(InpensoTheme.hairline)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(daysRemainingInMonth) days left")
                                .font(InpensoTheme.body(14, weight: .semibold))
                                .foregroundStyle(InpensoTheme.ink)
                            Text("in this month")
                                .font(InpensoTheme.label(11))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(budgetRemainingPerDay, format: .currency(code: currencyCode))
                                .font(InpensoTheme.displayAmount(16))
                                .foregroundStyle(InpensoTheme.ink)
                            Text("per day left")
                                .font(InpensoTheme.label(11))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                    }
                }
            }
        }
    }

    private func budgetMetric(title: String, value: Double, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title.uppercased())
                .font(InpensoTheme.label(10, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
            Text(value, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(20))
                .foregroundStyle(InpensoTheme.ink)
        }
    }
}

struct BudgetRecommendationsView: View {
    @EnvironmentObject private var categoryStore: CategoryStore

    let biggestExpenseCategory: (categoryID: String, amount: Double)?
    let totalSpent: Double
    let currentBudget: Double
    let daysRemainingInMonth: Int
    let suggestedBudget: Double
    let currencyCode: String

    init(
        biggestExpenseCategory: (categoryID: String, amount: Double)?,
        totalSpent: Double,
        currentBudget: Double,
        daysRemainingInMonth: Int,
        suggestedBudget: Double,
        currencyCode: String? = nil
    ) {
        self.biggestExpenseCategory = biggestExpenseCategory
        self.totalSpent = totalSpent
        self.currentBudget = currentBudget
        self.daysRemainingInMonth = daysRemainingInMonth
        self.suggestedBudget = suggestedBudget
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Recommendations")

                VStack(spacing: InpensoTheme.Space.md) {
                    if let (categoryID, amount) = biggestExpenseCategory, totalSpent > currentBudget {
                        recommendationRow(
                            label: "Consider reducing",
                            detail: categoryStore.category(for: categoryID).displayName,
                            value: amount
                        )
                    }

                    if totalSpent > currentBudget && daysRemainingInMonth > 0 {
                        Text("Spend \(currentBudget * 0.9 - totalSpent, format: .currency(code: currencyCode)) less than budgeted for the rest of the month to get back on track.")
                            .font(InpensoTheme.body(13))
                            .foregroundStyle(InpensoTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if suggestedBudget > 0 && abs(suggestedBudget - currentBudget) / currentBudget > 0.1 {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Suggested next month")
                                    .font(InpensoTheme.label(11, weight: .semibold))
                                    .foregroundStyle(InpensoTheme.muted)
                                Text(suggestedBudget, format: .currency(code: currencyCode))
                                    .font(InpensoTheme.displayAmount(18))
                                    .foregroundStyle(InpensoTheme.ink)
                            }
                            Spacer()
                            if suggestedBudget > currentBudget {
                                Text("+\(Int((suggestedBudget - currentBudget) / currentBudget * 100))%")
                                    .font(InpensoTheme.label(12, weight: .bold))
                                    .foregroundStyle(InpensoTheme.copperSoft)
                            } else {
                                Text("-\(Int((currentBudget - suggestedBudget) / currentBudget * 100))%")
                                    .font(InpensoTheme.label(12, weight: .bold))
                                    .foregroundStyle(InpensoTheme.surplus)
                            }
                        }
                    }
                }
            }
        }
    }

    private func recommendationRow(label: String, detail: String, value: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(InpensoTheme.label(11, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
                Text(detail)
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
            }
            Spacer()
            Text(value, format: .currency(code: currencyCode))
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(InpensoTheme.danger)
        }
    }
}

struct BudgetHistoryView: View {
    struct BudgetComplianceData {
        let month: Int
        let year: Int
        let monthName: String
        let compliancePercent: Double
        let color: Color
    }

    let complianceData: [BudgetComplianceData]

    var body: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Budget History")

            if complianceData.isEmpty {
                SurfacePanel(padding: InpensoTheme.Space.md) {
                    Text("Not enough budget history yet")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            } else {
                SurfacePanel(padding: InpensoTheme.Space.md) {
                    VStack(spacing: InpensoTheme.Space.sm) {
                        Chart {
                            ForEach(complianceData, id: \.month) { data in
                                BarMark(
                                    x: .value("Month", data.monthName),
                                    y: .value("Percent", data.compliancePercent)
                                )
                                .foregroundStyle(data.color)
                                .cornerRadius(2)
                            }

                            RuleMark(y: .value("Budget", 100))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                        .frame(height: 180)
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(InpensoTheme.hairline)
                                AxisValueLabel(format: Decimal.FormatStyle.Percent.percent)
                                    .font(InpensoTheme.label(10))
                                    .foregroundStyle(InpensoTheme.muted)
                            }
                        }

                        let onBudgetMonths = complianceData.filter { $0.compliancePercent <= 100 }.count
                        Text("\(onBudgetMonths) of \(complianceData.count) months on or under budget")
                            .font(InpensoTheme.label(11))
                            .foregroundStyle(InpensoTheme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: InpensoTheme.Space.lg) {
            BudgetInputView(currentBudget: .constant(2500), onSave: {})
            BudgetStatusView(
                totalSpent: 1875.50, currentBudget: 2500,
                daysRemainingInMonth: 14, budgetRemainingPerDay: 44.61
            )
            BudgetRecommendationsView(
                biggestExpenseCategory: (Category.food.categoryID, 450.50),
                totalSpent: 1875.50, currentBudget: 2500,
                daysRemainingInMonth: 14, suggestedBudget: 2700
            )
            .environmentObject(CategoryStore())
        }
        .padding(InpensoTheme.Space.screen)
    }
    .background(InpensoTheme.foam)
}
