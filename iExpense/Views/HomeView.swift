//
//  HomeView.swift
//  iExpense
//
//  North home — brand-led cash overview for a fresh app feel.
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
    @State private var showInsights = false

    private var currencyCode: String { settingsViewModel.selectedCurrency }
    private var periodSpent: Double { viewModel.spent(for: period) }
    private var periodIncome: Double { viewModel.income(for: period) }
    private var periodNet: Double { viewModel.net(for: period) }

    private var topCategories: [(String, Double)] {
        PeriodTotals.categoryBreakdown(from: viewModel.expenses, period: period)
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { ($0.key, $0.value) }
    }

    private var recent: [Expense] { viewModel.recentExpenses(limit: 6) }

    private var monthTitle: String {
        Date.now.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                        brandHeader
                        heroCard
                        actionStack
                        tripsBanner
                        if period == .month, analyticsViewModel.currentBudget > 0 {
                            budgetStrip
                        }
                        if !topCategories.isEmpty {
                            categoriesSection
                        }
                        recentSection
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, InpensoTheme.Space.bottomClearance)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedExpenseToEdit) { expense in
                EditExpenseView(viewModel: viewModel, expense: expense)
            }
            .sheet(isPresented: $showReceiptScan) {
                ReceiptScanView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showInsights) {
                AnalyticsView(analyticsViewModel: analyticsViewModel)
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

    // MARK: - Brand header

    private var brandHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Inpenso")
                    .font(InpensoTheme.brandFont(28, weight: .heavy))
                    .foregroundStyle(InpensoTheme.ink)
                Text(monthTitle)
                    .font(InpensoTheme.label(13))
                    .foregroundStyle(InpensoTheme.muted)
            }
            Spacer()
            Button {
                showReceiptScan = true
            } label: {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(InpensoTheme.panelFill)
                            .shadow(color: InpensoTheme.ink.opacity(0.06), radius: 8, y: 2)
                    )
            }
            .accessibilityLabel("Scan receipt")
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.lg) {
            PeriodSelector(period: $period)

            VStack(alignment: .leading, spacing: 6) {
                Text(period.spentLabel)
                    .font(InpensoTheme.label(13, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
                Text(periodSpent, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(42))
                    .foregroundStyle(InpensoTheme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 0) {
                heroStat("Income", periodIncome, InpensoTheme.incomeTint)
                Rectangle()
                    .fill(InpensoTheme.hairline)
                    .frame(width: 1, height: 40)
                    .padding(.horizontal, InpensoTheme.Space.md)
                heroStat("Net", periodNet, periodNet >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint)
            }
        }
        .padding(InpensoTheme.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.hero, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .shadow(color: InpensoTheme.ink.opacity(0.05), radius: 16, y: 6)
        )
    }

    private func heroStat(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
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

    private var actionStack: some View {
        VStack(spacing: InpensoTheme.Space.sm) {
            Button {
                HapticFeedback.impact()
                onAddTransaction(.expense)
            } label: {
                Label("Add expense", systemImage: "minus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.expenseTint))

            Button {
                HapticFeedback.impact()
                onAddTransaction(.income)
            } label: {
                Label("Add income", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.incomeTint))
        }
    }

    private var tripsBanner: some View {
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("SwitchToTripsTab"), object: nil)
        } label: {
            HStack(spacing: InpensoTheme.Space.md) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Trips with friends")
                        .font(InpensoTheme.body(16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Create or join with an invite code")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(InpensoTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [InpensoTheme.tide, Color(inpensoHex: "#2554D6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Budget

    private var budgetStrip: some View {
        let progress = min(1.0, analyticsViewModel.totalSpent / max(analyticsViewModel.currentBudget, 1))
        return SurfacePanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Monthly budget")
                        .font(InpensoTheme.label(13, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(InpensoTheme.label(13, weight: .bold))
                        .foregroundStyle(progress > 0.9 ? InpensoTheme.danger : InpensoTheme.tide)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(InpensoTheme.mist)
                        Capsule()
                            .fill(progress > 0.9 ? InpensoTheme.danger : InpensoTheme.tide)
                            .frame(width: max(4, geo.size.width * progress))
                    }
                }
                .frame(height: 8)
                Text("\(analyticsViewModel.daysRemainingInMonth) days left")
                    .font(InpensoTheme.label(12))
                    .foregroundStyle(InpensoTheme.muted)
            }
        }
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Top categories", actionTitle: "Insights") {
                showInsights = true
            }

            VStack(spacing: InpensoTheme.Space.sm) {
                ForEach(topCategories, id: \.0) { id, amount in
                    let category = categoryStore.category(for: id)
                    let share = periodSpent > 0 ? amount / periodSpent : 0
                    HStack(spacing: InpensoTheme.Space.sm) {
                        Image(systemName: category.iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(category.color)
                            .frame(width: 40, height: 40)
                            .background(
                                category.color.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                            )
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(category.displayName)
                                    .font(InpensoTheme.body(15, weight: .semibold))
                                    .foregroundStyle(InpensoTheme.ink)
                                Spacer()
                                Text(amount, format: .currency(code: currencyCode))
                                    .font(InpensoTheme.displayAmount(14))
                                    .foregroundStyle(InpensoTheme.slate)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(InpensoTheme.mist)
                                    Capsule()
                                        .fill(category.color)
                                        .frame(width: max(4, geo.size.width * share))
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                    .padding(InpensoTheme.Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                            .fill(InpensoTheme.panelFill)
                    )
                }
            }
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Recent", actionTitle: "See all") {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToExpensesTab"), object: nil)
            }

            if recent.isEmpty {
                SurfacePanel(padding: InpensoTheme.Space.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start tracking")
                            .font(InpensoTheme.body(17, weight: .bold))
                            .foregroundStyle(InpensoTheme.ink)
                        Text("Add an expense or income to see your cashflow here.")
                            .font(InpensoTheme.body(14))
                            .foregroundStyle(InpensoTheme.muted)
                    }
                }
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
                            .padding(.horizontal, InpensoTheme.Space.md)
                            .padding(.vertical, InpensoTheme.Space.sm)
                        }
                        .buttonStyle(.plain)

                        if index < recent.count - 1 {
                            Divider().overlay(InpensoTheme.hairline).padding(.leading, 68)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                        .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 12, y: 4)
                )
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
