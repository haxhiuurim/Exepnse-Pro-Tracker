//
//  HomeView.swift
//  iExpense
//
//  Cash overview — spent first, Expense & Income always visible.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var pro: ProEntitlementManager

    @ObservedObject var viewModel: ExpenseViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    @Binding var showQuickAdd: Bool
    var onAddTransaction: (TransactionType) -> Void

    @State private var period: SpendingPeriod = .month
    @State private var selectedExpenseToEdit: Expense?
    @State private var showReceiptScan = false

    private var currencyCode: String { settingsViewModel.selectedCurrency }
    private var periodSpent: Double { viewModel.spent(for: period) }
    private var periodIncome: Double { viewModel.income(for: period) }
    private var periodNet: Double { viewModel.net(for: period) }

    private var topCategories: [(String, Double)] {
        PeriodTotals.categoryBreakdown(from: viewModel.expenses, period: period)
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { ($0.key, $0.value) }
    }

    private var recent: [Expense] { viewModel.recentExpenses(limit: 8) }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        PeriodSelector(period: $period)
                            .padding(.horizontal, InpensoTheme.Space.screen)
                            .padding(.top, InpensoTheme.Space.md)

                        totalsBlock
                            .padding(.horizontal, InpensoTheme.Space.screen)
                            .padding(.top, InpensoTheme.Space.xl)

                        actionRow
                            .padding(.horizontal, InpensoTheme.Space.screen)
                            .padding(.top, InpensoTheme.Space.lg)

                        if period == .month, analyticsViewModel.currentBudget > 0 {
                            budgetStrip
                                .padding(.horizontal, InpensoTheme.Space.screen)
                                .padding(.top, InpensoTheme.Space.lg)
                        }

                        if !topCategories.isEmpty {
                            categoriesSection
                                .padding(.top, InpensoTheme.Space.section)
                        }

                        recentSection
                            .padding(.top, InpensoTheme.Space.section)
                            .padding(.bottom, InpensoTheme.Space.bottomClearance)
                    }
                }
            }
            .navigationTitle("Money")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showReceiptScan = true
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .accessibilityLabel("Scan receipt")
                }
            }
            .sheet(item: $selectedExpenseToEdit) { expense in
                EditExpenseView(viewModel: viewModel, expense: expense)
            }
            .sheet(isPresented: $showReceiptScan) {
                ReceiptScanView(viewModel: viewModel)
            }
            .onAppear {
                pro.maybePresentSpecialOffer()
                if pro.isPro {
                    SpentTodayLiveActivity.startOrUpdate(
                        amount: viewModel.spent(for: .today),
                        currencyCode: currencyCode,
                        isPro: true
                    )
                }
            }
            .onChange(of: viewModel.expenses) {
                if pro.isPro {
                    SpentTodayLiveActivity.startOrUpdate(
                        amount: viewModel.spent(for: .today),
                        currencyCode: currencyCode,
                        isPro: true
                    )
                }
            }
        }
    }

    // MARK: - Totals

    private var totalsBlock: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(period.spentLabel)
                    .font(InpensoTheme.label(14))
                    .foregroundStyle(InpensoTheme.muted)

                Text(periodSpent, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(44))
                    .foregroundStyle(InpensoTheme.ink)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 0) {
                sideStat(
                    label: "Income",
                    value: periodIncome,
                    color: InpensoTheme.incomeTint
                )
                Rectangle()
                    .fill(InpensoTheme.hairline)
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, InpensoTheme.Space.md)
                sideStat(
                    label: "Net",
                    value: periodNet,
                    color: periodNet >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint
                )
            }
        }
    }

    private func sideStat(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(InpensoTheme.label(12))
                .foregroundStyle(InpensoTheme.muted)
            Text(value, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(18))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            Button {
                HapticFeedback.impact()
                onAddTransaction(.expense)
            } label: {
                Label("Expense", systemImage: "minus")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.expenseTint))
            .accessibilityHint("Log an expense")

            Button {
                HapticFeedback.impact()
                onAddTransaction(.income)
            } label: {
                Label("Income", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.incomeTint))
            .accessibilityHint("Log income")
        }
    }

    // MARK: - Budget

    private var budgetStrip: some View {
        let progress = min(1.0, analyticsViewModel.totalSpent / max(analyticsViewModel.currentBudget, 1))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monthly budget")
                    .font(InpensoTheme.label(13))
                    .foregroundStyle(InpensoTheme.muted)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(InpensoTheme.label(13, weight: .semibold))
                    .foregroundStyle(progress > 0.9 ? InpensoTheme.danger : InpensoTheme.ink)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(InpensoTheme.mistDeep)
                    Capsule()
                        .fill(progress > 0.9 ? InpensoTheme.danger : InpensoTheme.ink)
                        .frame(width: max(3, geo.size.width * progress))
                }
            }
            .frame(height: 5)

            Text("\(analyticsViewModel.daysRemainingInMonth) days left · \(analyticsViewModel.currentBudget.formatted(.currency(code: currencyCode))) set")
                .font(InpensoTheme.label(12))
                .foregroundStyle(InpensoTheme.muted)
        }
        .padding(InpensoTheme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                .fill(InpensoTheme.panelFill)
        )
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Top categories")
                .padding(.horizontal, InpensoTheme.Space.screen)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: InpensoTheme.Space.sm) {
                    ForEach(topCategories, id: \.0) { id, amount in
                        let category = categoryStore.category(for: id)
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(category.color)
                                .frame(width: 36, height: 36)
                                .background(
                                    category.color.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                )

                            Text(category.displayName)
                                .font(InpensoTheme.label(13, weight: .medium))
                                .foregroundStyle(InpensoTheme.ink)
                                .lineLimit(1)

                            Text(amount, format: .currency(code: currencyCode))
                                .font(InpensoTheme.displayAmount(15))
                                .foregroundStyle(InpensoTheme.slate)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(InpensoTheme.Space.md)
                        .frame(width: 132, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                                .fill(InpensoTheme.panelFill)
                        )
                    }
                }
                .padding(.horizontal, InpensoTheme.Space.screen)
            }
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Recent", actionTitle: "See all") {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToExpensesTab"), object: nil)
            }
            .padding(.horizontal, InpensoTheme.Space.screen)

            if recent.isEmpty {
                VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                    Text("No transactions yet")
                        .font(InpensoTheme.body(16, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("Use Expense or Income above to add your first entry.")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(InpensoTheme.Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                )
                .padding(.horizontal, InpensoTheme.Space.screen)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, expense in
                        Button {
                            selectedExpenseToEdit = expense
                        } label: {
                            TransactionRowView(
                                expense: expense,
                                currencyCode: currencyCode,
                                category: categoryStore.category(for: expense)
                            )
                            .padding(.horizontal, InpensoTheme.Space.screen)
                            .padding(.vertical, InpensoTheme.Space.sm)
                        }
                        .buttonStyle(.plain)

                        if index < recent.count - 1 {
                            Divider()
                                .overlay(InpensoTheme.hairline)
                                .padding(.leading, InpensoTheme.Space.screen + 48)
                        }
                    }
                }
                .background(InpensoTheme.panelFill)
            }
        }
    }
}

#Preview {
    HomeView(
        viewModel: ExpenseViewModel(),
        analyticsViewModel: AnalyticsViewModel(expenses: []),
        showQuickAdd: .constant(false),
        onAddTransaction: { _ in }
    )
    .environmentObject(SettingsViewModel())
    .environmentObject(CategoryStore())
    .environmentObject(ProEntitlementManager.shared)
}
