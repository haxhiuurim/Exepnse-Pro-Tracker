//
//  CategoryBudgetsView.swift
//  iExpense
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
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            InpensoSectionHeader(title: "Category Budgets")

            Text(pro.isPro
                 ? "Set a monthly cap per category. Progress reflects this month's spending."
                 : "Free includes \(FreeTierLimits.categoryBudgets) category budgets. Pro unlocks unlimited + alerts.")
                .font(InpensoTheme.body(13))
                .foregroundStyle(InpensoTheme.muted)

            if !pro.isPro {
                ProGateBanner(message: "You're using \(activeBudgetCount)/\(FreeTierLimits.categoryBudgets) free category budgets.") {
                    pro.openPaywall()
                }
            }

            SurfacePanel(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(categoryStore.allCategories.enumerated()), id: \.element.id) { index, category in
                        categoryBudgetRow(category)
                        if index < categoryStore.allCategories.count - 1 {
                            Divider().overlay(InpensoTheme.hairline)
                                .padding(.leading, InpensoTheme.Space.md)
                        }
                    }
                }
            }

            Button {
                persistDrafts()
            } label: {
                Text("Save Category Budgets")
            }
            .buttonStyle(InpensoPrimaryButtonStyle())
        }
        .onAppear { hydrateDrafts() }
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

        return VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            HStack(spacing: InpensoTheme.Space.sm) {
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: category.iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(category.color)
                    }

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
                .frame(width: 80)
                .padding(.horizontal, InpensoTheme.Space.sm)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        .fill(InpensoTheme.mist)
                )
            }

            if limit > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(InpensoTheme.mist)
                        Capsule()
                            .fill(progressColor(progress))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)

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
        .padding(InpensoTheme.Space.md)
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
            let allowed = budgets
                .sorted { (analyticsViewModel.spendingByCategory[$0.key] ?? 0) > (analyticsViewModel.spendingByCategory[$1.key] ?? 0) }
                .prefix(FreeTierLimits.categoryBudgets)
            budgets = Dictionary(uniqueKeysWithValues: allowed.map { ($0.key, $0.value) })
            showLimitAlert = true
        }

        analyticsViewModel.saveCategoryBudgets(budgets)
        if !showLimitAlert { showSaved = true }
        HapticFeedback.success()
    }
}
