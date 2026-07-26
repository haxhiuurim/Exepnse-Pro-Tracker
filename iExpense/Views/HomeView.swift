//
//  HomeView.swift
//  iExpense
//
//  Tide Ledger home — brand-first cashflow with period widgets and quick add.
//

import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var pro: ProEntitlementManager

    @ObservedObject var viewModel: ExpenseViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    @Binding var showQuickAdd: Bool

    @State private var period: SpendingPeriod = .month
    @State private var selectedExpenseToEdit: Expense?
    @State private var showReceiptScan = false
    @State private var heroAppeared = false
    @State private var contentAppeared = false

    private var currencyCode: String {
        settingsViewModel.selectedCurrency
    }

    private var periodSpent: Double {
        viewModel.spent(for: period)
    }

    private var periodIncome: Double {
        viewModel.income(for: period)
    }

    private var periodNet: Double {
        viewModel.net(for: period)
    }

    private var periodCategories: [(String, Double)] {
        PeriodTotals.categoryBreakdown(from: viewModel.expenses, period: period)
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        heroSection
                        if !pro.isPro {
                            upgradeBanner
                        } else if period == .today {
                            SpentTodayLiveActivityBanner(
                                amount: periodSpent,
                                currencyCode: currencyCode
                            )
                            .opacity(contentAppeared ? 1 : 0)
                        }
                        periodWidgets
                        quickActions
                        categoryPulse
                        recentSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedExpenseToEdit) { expense in
                EditExpenseView(viewModel: viewModel, expense: expense)
            }
            .sheet(isPresented: $showReceiptScan) {
                ReceiptScanView(viewModel: viewModel)
            }
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    heroAppeared = true
                }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.84).delay(0.12)) {
                    contentAppeared = true
                }
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

    private var upgradeBanner: some View {
        Button {
            pro.openPaywall(plan: .yearly)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Inpenso Pro")
                        .font(InpensoTheme.brandFont(20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Unlimited OCR, sync, goals & more — no ads.")
                        .font(InpensoTheme.body(13))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Text("Upgrade")
                    .font(InpensoTheme.label(13, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(InpensoTheme.seafoam, in: Capsule(style: .continuous))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [InpensoTheme.ink, InpensoTheme.inkSoft, InpensoTheme.copper.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: InpensoTheme.ink.opacity(0.2), radius: 16, y: 8)
            )
        }
        .buttonStyle(.plain)
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared ? 0 : 12)
    }

    // MARK: - Hero (brand first)

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text("Inpenso")
                    .font(InpensoTheme.brandFont(42, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 16)

                Spacer()

                if !pro.isPro {
                    UpgradePillButton {
                        pro.openPaywall(plan: .yearly)
                    }
                    .opacity(heroAppeared ? 1 : 0)
                } else {
                    Text("PRO")
                        .font(InpensoTheme.label(11, weight: .bold))
                        .foregroundStyle(InpensoTheme.seafoam)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(InpensoTheme.ink, in: Capsule())
                        .opacity(heroAppeared ? 1 : 0)
                }
            }

            Text("Your money, clear as tide.")
                .font(InpensoTheme.body(16))
                .foregroundStyle(InpensoTheme.muted)
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 10)

            PeriodSelector(period: $period)
                .opacity(heroAppeared ? 1 : 0)

            VStack(alignment: .leading, spacing: 6) {
                Text(period.spentLabel.uppercased())
                    .font(InpensoTheme.label(11, weight: .bold))
                    .foregroundStyle(InpensoTheme.seafoam)
                    .tracking(1.4)

                Text(periodSpent, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(48))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                HStack(spacing: 18) {
                    miniMetric(label: "In", value: periodIncome, tint: InpensoTheme.seafoam)
                    miniMetric(label: "Net", value: periodNet, tint: periodNet >= 0 ? InpensoTheme.seafoam : InpensoTheme.copperSoft)
                }
                .padding(.top, 4)

                if period == .month, analyticsViewModel.currentBudget > 0 {
                    budgetBar
                        .padding(.top, 10)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [InpensoTheme.ink, InpensoTheme.inkSoft, InpensoTheme.tide.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: InpensoTheme.ink.opacity(0.25), radius: 24, x: 0, y: 14)
            )
            .scaleEffect(heroAppeared ? 1 : 0.96)
            .opacity(heroAppeared ? 1 : 0)
        }
    }

    private func miniMetric(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(InpensoTheme.label(11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
            Text(value, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(15))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var budgetBar: some View {
        let progress = min(1.0, analyticsViewModel.totalSpent / max(analyticsViewModel.currentBudget, 1))
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(progress > 0.9 ? InpensoTheme.copperSoft : InpensoTheme.seafoam)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int(progress * 100))% of monthly budget")
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(analyticsViewModel.daysRemainingInMonth)d left")
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Period widgets strip

    private var periodWidgets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("At a glance")
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(InpensoTheme.slate)

            HStack(spacing: 10) {
                ForEach(SpendingPeriod.allCases) { item in
                    periodWidgetTile(item)
                }
            }
        }
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared ? 0 : 16)
    }

    private func periodWidgetTile(_ item: SpendingPeriod) -> some View {
        let amount = viewModel.spent(for: item)
        let selected = period == item

        return Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                period = item
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.shortTitle)
                    .font(InpensoTheme.label(11, weight: .bold))
                    .foregroundStyle(selected ? InpensoTheme.copper : InpensoTheme.muted)
                Text(amount, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(15))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selected ? InpensoTheme.copper.opacity(0.45) : InpensoTheme.ink.opacity(0.06), lineWidth: selected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                showQuickAdd = true
            } label: {
                Label("Add spend", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle())

            Button {
                showReceiptScan = true
            } label: {
                Label("Scan", systemImage: "doc.text.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoSecondaryButtonStyle())
        }
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared ? 0 : 12)
    }

    // MARK: - Categories

    private var categoryPulse: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Where it went")
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(InpensoTheme.slate)

            if periodCategories.isEmpty {
                Text("No spending in this period yet.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(periodCategories, id: \.0) { id, amount in
                        let category = categoryStore.category(for: id)
                        let share = periodSpent > 0 ? amount / periodSpent : 0

                        HStack(spacing: 12) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(category.color)
                                .frame(width: 32, height: 32)
                                .background(category.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(category.displayName)
                                        .font(InpensoTheme.body(14, weight: .semibold))
                                        .foregroundStyle(InpensoTheme.ink)
                                    Spacer()
                                    Text(amount, format: .currency(code: currencyCode))
                                        .font(InpensoTheme.label(13, weight: .bold))
                                        .foregroundStyle(InpensoTheme.slate)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(InpensoTheme.ink.opacity(0.06))
                                        Capsule()
                                            .fill(category.color.opacity(0.85))
                                            .frame(width: geo.size.width * share)
                                    }
                                }
                                .frame(height: 5)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
            }
        }
        .opacity(contentAppeared ? 1 : 0)
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent")
                    .font(InpensoTheme.label(13, weight: .semibold))
                    .foregroundStyle(InpensoTheme.slate)
                Spacer()
                Button("See all") {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToExpensesTab"), object: nil)
                }
                .font(InpensoTheme.label(12, weight: .bold))
                .foregroundStyle(InpensoTheme.copper)
            }

            if viewModel.expenses.isEmpty {
                Text("Tap Add spend to log your first transaction.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
            } else {
                VStack(spacing: 4) {
                    ForEach(viewModel.recentExpenses(limit: 5)) { expense in
                        Button {
                            selectedExpenseToEdit = expense
                        } label: {
                            TransactionRowView(
                                expense: expense,
                                currencyCode: currencyCode,
                                category: categoryStore.category(for: expense)
                            )
                        }
                        .buttonStyle(.plain)

                        if expense.id != viewModel.recentExpenses(limit: 5).last?.id {
                            Divider().opacity(0.35)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
            }
        }
        .opacity(contentAppeared ? 1 : 0)
    }
}

#Preview {
    HomeView(
        viewModel: ExpenseViewModel(),
        analyticsViewModel: AnalyticsViewModel(expenses: []),
        showQuickAdd: .constant(false)
    )
    .environmentObject(SettingsViewModel())
    .environmentObject(CategoryStore())
    .environmentObject(ProEntitlementManager.shared)
}
