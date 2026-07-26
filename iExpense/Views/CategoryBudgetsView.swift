//
//  CategoryBudgetsView.swift
//  iExpense
//
//  Set and track per-category monthly spending limits.
//

import SwiftUI

struct CategoryBudgetsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var pro: ProEntitlementManager
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    @State private var draftLimits: [String: String] = [:]
    @State private var showSaved = false
    @State private var showLimitAlert = false

    private var currencyCode: String { settingsViewModel.selectedCurrency }

    private var activeBudgetCount: Int {
        analyticsViewModel.categoryBudgets.values.filter { $0 > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category budgets")
                .font(InpensoTheme.label(14, weight: .semibold))
                .foregroundStyle(InpensoTheme.slate)

            Text(pro.isPro
                 ? "Set a monthly cap for each category. Progress uses this month’s spending."
                 : "Free includes \(FreeTierLimits.categoryBudgets) category budgets. Pro unlocks unlimited + alerts.")
                .font(InpensoTheme.body(13))
                .foregroundStyle(InpensoTheme.muted)

            if !pro.isPro {
                ProGateBanner(message: "You’re using \(activeBudgetCount)/\(FreeTierLimits.categoryBudgets) free category budgets.") {
                    pro.openPaywall()
                }
            }

            VStack(spacing: 12) {
                ForEach(categoryStore.allCategories) { category in
                    categoryBudgetRow(category)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )

            Button {
                persistDrafts()
            } label: {
                Text("Save category budgets")
            }
            .buttonStyle(InpensoPrimaryButtonStyle())
        }
        .onAppear {
            hydrateDrafts()
        }
        .alert("Category budgets saved", isPresented: $showSaved) {
            Button("OK", role: .cancel) { }
        }
        .alert("Free limit reached", isPresented: $showLimitAlert) {
            Button("Upgrade") { pro.openPaywall() }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Free plans can set \(FreeTierLimits.categoryBudgets) category budgets. Upgrade for unlimited caps and alerts.")
        }
    }

    private func categoryBudgetRow(_ category: FinanceCategory) -> some View {
        let spent = analyticsViewModel.spendingByCategory[category.id] ?? 0
        let limit = Double(draftLimits[category.id] ?? "") ?? analyticsViewModel.categoryBudgets[category.id] ?? 0
        let progress = CategoryBudgetStore.progress(spent: spent, limit: limit)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: category.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(category.color)
                    .frame(width: 30, height: 30)
                    .background(category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(category.displayName)
                    .font(InpensoTheme.body(14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)

                Spacer()

                TextField("0", text: Binding(
                    get: { draftLimits[category.id] ?? "" },
                    set: { draftLimits[category.id] = $0 }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(InpensoTheme.displayAmount(15))
                .frame(width: 88)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(InpensoTheme.mist.opacity(0.8))
                )
            }

            if limit > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(InpensoTheme.ink.opacity(0.06))
                        Capsule()
                            .fill(progressColor(progress))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 5)

                HStack {
                    Text(spent, format: .currency(code: currencyCode))
                        .font(InpensoTheme.label(11))
                        .foregroundStyle(InpensoTheme.muted)
                    Spacer()
                    Text("\(Int(progress * 100))% of \(limit.formatted(.currency(code: currencyCode)))")
                        .font(InpensoTheme.label(11, weight: .semibold))
                        .foregroundStyle(progress >= 1 ? InpensoTheme.danger : InpensoTheme.slate)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1 { return InpensoTheme.danger }
        if progress >= 0.85 { return InpensoTheme.copper }
        return InpensoTheme.tide
    }

    private func hydrateDrafts() {
        var drafts: [String: String] = [:]
        for category in categoryStore.allCategories {
            if let limit = analyticsViewModel.categoryBudgets[category.id], limit > 0 {
                drafts[category.id] = String(format: "%.0f", limit)
            } else {
                drafts[category.id] = ""
            }
        }
        draftLimits = drafts
    }

    private func persistDrafts() {
        var budgets: [String: Double] = [:]
        for (id, text) in draftLimits {
            let cleaned = text.replacingOccurrences(of: ",", with: ".")
            if let value = Double(cleaned), value > 0 {
                budgets[id] = value
            }
        }

        if !pro.canAddCategoryBudget(currentCount: budgets.count) {
            // Keep only the first N free budgets by highest existing spend
            let allowed = budgets
                .sorted { (analyticsViewModel.spendingByCategory[$0.key] ?? 0) > (analyticsViewModel.spendingByCategory[$1.key] ?? 0) }
                .prefix(FreeTierLimits.categoryBudgets)
            budgets = Dictionary(uniqueKeysWithValues: allowed.map { ($0.key, $0.value) })
            showLimitAlert = true
        }

        analyticsViewModel.saveCategoryBudgets(budgets)
        if !showLimitAlert {
            showSaved = true
        }
        HapticFeedback.success()
    }
}
