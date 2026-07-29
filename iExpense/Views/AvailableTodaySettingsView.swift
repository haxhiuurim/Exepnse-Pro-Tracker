//
//  AvailableTodaySettingsView.swift
//  iExpense
//

import SwiftUI

struct AvailableTodaySettingsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @ObservedObject private var onboarding = OnboardingStore.shared
    @ObservedObject private var recurring = RecurringTransactionService.shared
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel

    @State private var incomeText = ""
    @State private var savingsText = ""

    private var currencyCode: String { settingsViewModel.selectedCurrency }

    private var result: AvailableTodayResult {
        AvailableTodayCalculator.compute(
            expenses: expenseViewModel.expenses,
            recurring: recurring.items,
            monthlyIncomeOverride: onboarding.monthlyIncome,
            monthlySavingsTarget: onboarding.monthlySavingsTarget
        )
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available today")
                            .font(InpensoTheme.label(13, weight: .semibold))
                            .foregroundStyle(InpensoTheme.muted)
                        Text(result.amount, format: .currency(code: currencyCode))
                            .font(InpensoTheme.displayAmount(36))
                            .foregroundStyle(InpensoTheme.tide)
                        Text("Income − bills − savings − spent, split across remaining days.")
                            .font(InpensoTheme.body(14))
                            .foregroundStyle(InpensoTheme.muted)
                    }
                    .padding(InpensoTheme.Space.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)

                    VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                        Text("Inputs")
                            .font(InpensoTheme.sectionLabel())
                            .foregroundStyle(InpensoTheme.muted)

                        labeledField("Monthly income", text: $incomeText)
                        labeledField("Monthly savings target", text: $savingsText)

                        Button("Save") {
                            onboarding.monthlyIncome = Double(incomeText.replacingOccurrences(of: ",", with: ".")) ?? 0
                            onboarding.monthlySavingsTarget = Double(savingsText.replacingOccurrences(of: ",", with: ".")) ?? 0
                            HapticFeedback.success()
                        }
                        .buttonStyle(InpensoPrimaryButtonStyle())
                    }

                    Text("Bills come from active recurring expenses (\(result.monthlyBills.formatted(.currency(code: currencyCode)))/mo).")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                }
                .padding(InpensoTheme.Space.screen)
            }
        }
        .navigationTitle("Available Today")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            incomeText = onboarding.monthlyIncome > 0 ? String(format: "%.2f", onboarding.monthlyIncome) : ""
            savingsText = onboarding.monthlySavingsTarget > 0 ? String(format: "%.2f", onboarding.monthlySavingsTarget) : ""
        }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(InpensoTheme.label(13))
                .foregroundStyle(InpensoTheme.muted)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .padding(InpensoTheme.Space.md)
                .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
        }
    }
}
