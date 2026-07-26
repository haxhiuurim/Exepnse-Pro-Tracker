//
//  HomeView.swift
//  iExpense
//
//  Tide Ledger home — brand-first cashflow with refined spacing rhythm.
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

    private var currencyCode: String { settingsViewModel.selectedCurrency }
    private var periodSpent: Double { viewModel.spent(for: period) }
    private var periodIncome: Double { viewModel.income(for: period) }
    private var periodNet: Double { viewModel.net(for: period) }

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
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                        heroSection
                        if !pro.isPro {
                            upgradeStrip
                                .reveal(contentAppeared, delay: 0.05)
                        } else if period == .today {
                            SpentTodayLiveActivityBanner(
                                amount: periodSpent,
                                currencyCode: currencyCode
                            )
                            .reveal(contentAppeared, delay: 0.05)
                        }
                        periodWidgets
                            .reveal(contentAppeared, delay: 0.08)
                        quickActions
                            .reveal(contentAppeared, delay: 0.1)
                        categoryPulse
                            .reveal(contentAppeared, delay: 0.14)
                        recentSection
                            .reveal(contentAppeared, delay: 0.18)
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.top, InpensoTheme.Space.xs)
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
            .onAppear {
                withAnimation(InpensoTheme.Motion.gentle) { heroAppeared = true }
                withAnimation(InpensoTheme.Motion.reveal.delay(0.1)) { contentAppeared = true }
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

    // MARK: - Upgrade (slim — doesn't overpower brand hero)

    private var upgradeStrip: some View {
        Button {
            pro.openPaywall(plan: .yearly)
        } label: {
            HStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.seafoam)
                    .frame(width: 36, height: 36)
                    .background(InpensoTheme.seafoam.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Inpenso Pro")
                        .font(InpensoTheme.body(14, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("OCR, sync, goals — no ads · from \(ProPlan.yearly.displayPrice)/yr")
                        .font(InpensoTheme.label(11))
                        .foregroundStyle(InpensoTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 4)

                Text("Upgrade")
                    .font(InpensoTheme.label(12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [InpensoTheme.copper, InpensoTheme.copperSoft],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule(style: .continuous)
                    )
            }
            .padding(.horizontal, InpensoTheme.Space.md)
            .padding(.vertical, InpensoTheme.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .fill(Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                            .stroke(InpensoTheme.copper.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            HStack(alignment: .center) {
                Text("Inpenso")
                    .font(InpensoTheme.brandFont(40, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                    .reveal(heroAppeared)

                Spacer()

                if !pro.isPro {
                    UpgradePillButton(compact: true) {
                        pro.openPaywall(plan: .yearly)
                    }
                    .reveal(heroAppeared, delay: 0.04)
                } else {
                    Text("PRO")
                        .font(InpensoTheme.label(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(InpensoTheme.seafoam)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(InpensoTheme.ink, in: Capsule())
                        .reveal(heroAppeared, delay: 0.04)
                }
            }

            Text("Your money, clear as tide.")
                .font(InpensoTheme.body(15))
                .foregroundStyle(InpensoTheme.muted)
                .reveal(heroAppeared, delay: 0.05)

            PeriodSelector(period: $period)
                .reveal(heroAppeared, delay: 0.08)

            cashPanel
                .scaleEffect(heroAppeared ? 1 : 0.97)
                .opacity(heroAppeared ? 1 : 0)
                .animation(InpensoTheme.Motion.gentle.delay(0.06), value: heroAppeared)
        }
    }

    private var cashPanel: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text(period.spentLabel.uppercased())
                .font(InpensoTheme.label(11, weight: .bold))
                .foregroundStyle(InpensoTheme.seafoam)
                .tracking(1.5)

            Text(periodSpent, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(44))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(InpensoTheme.Motion.snappy, value: periodSpent)

            HStack(spacing: 0) {
                miniMetric(label: "Income", value: periodIncome, tint: InpensoTheme.seafoam)
                Spacer()
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 1, height: 28)
                Spacer()
                miniMetric(label: "Net", value: periodNet, tint: periodNet >= 0 ? InpensoTheme.seafoam : InpensoTheme.copperSoft)
            }
            .padding(.top, InpensoTheme.Space.xxs)

            if period == .month, analyticsViewModel.currentBudget > 0 {
                budgetBar
                    .padding(.top, InpensoTheme.Space.xs)
            }
        }
        .padding(InpensoTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [InpensoTheme.ink, InpensoTheme.inkSoft, InpensoTheme.tide.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: InpensoTheme.ink.opacity(0.22), radius: 20, y: 12)
        )
    }

    private func miniMetric(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(InpensoTheme.label(11, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
            Text(value, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(16))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetBar: some View {
        let progress = min(1.0, analyticsViewModel.totalSpent / max(analyticsViewModel.currentBudget, 1))
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    Capsule()
                        .fill(progress > 0.9 ? InpensoTheme.copperSoft : InpensoTheme.seafoam)
                        .frame(width: max(6, geo.size.width * progress))
                        .animation(InpensoTheme.Motion.gentle, value: progress)
                }
            }
            .frame(height: 5)

            HStack {
                Text("\(Int(progress * 100))% of budget")
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text("\(analyticsViewModel.daysRemainingInMonth)d left")
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }

    // MARK: - At a glance

    private var periodWidgets: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "At a glance")

            HStack(spacing: InpensoTheme.Space.sm) {
                ForEach(SpendingPeriod.allCases) { item in
                    periodWidgetTile(item)
                }
            }
        }
    }

    private func periodWidgetTile(_ item: SpendingPeriod) -> some View {
        let amount = viewModel.spent(for: item)
        let selected = period == item

        return Button {
            HapticFeedback.selection()
            withAnimation(InpensoTheme.Motion.snappy) { period = item }
        } label: {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
                Text(item.shortTitle)
                    .font(InpensoTheme.label(11, weight: .bold))
                    .foregroundStyle(selected ? InpensoTheme.copper : InpensoTheme.muted)
                Text(amount, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(15))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(InpensoTheme.Space.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .fill(Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                            .stroke(
                                selected ? InpensoTheme.copper.opacity(0.4) : InpensoTheme.ink.opacity(0.05),
                                lineWidth: selected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var quickActions: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            Button { showQuickAdd = true } label: {
                Label("Add spend", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle())

            Button { showReceiptScan = true } label: {
                Label("Scan", systemImage: "doc.text.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoSecondaryButtonStyle())
        }
    }

    // MARK: - Categories

    private var categoryPulse: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Where it went")

            if periodCategories.isEmpty {
                SurfacePanel(padding: InpensoTheme.Space.md) {
                    Text("No spending in this period yet.")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                }
            } else {
                SurfacePanel(padding: InpensoTheme.Space.md) {
                    VStack(spacing: InpensoTheme.Space.md) {
                        ForEach(periodCategories, id: \.0) { id, amount in
                            let category = categoryStore.category(for: id)
                            let share = periodSpent > 0 ? amount / periodSpent : 0

                            HStack(spacing: InpensoTheme.Space.sm) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(category.color)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        category.color.opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                    )

                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(alignment: .firstTextBaseline) {
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
                                                .frame(width: max(4, geo.size.width * share))
                                        }
                                    }
                                    .frame(height: 4)
                                }
                            }
                        }
                    }
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

            if viewModel.expenses.isEmpty {
                SurfacePanel(padding: InpensoTheme.Space.md) {
                    Text("Tap Add spend to log your first transaction.")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                }
            } else {
                SurfacePanel(padding: InpensoTheme.Space.md - 2) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recentExpenses(limit: 5).enumerated()), id: \.element.id) { index, expense in
                            Button {
                                selectedExpenseToEdit = expense
                            } label: {
                                TransactionRowView(
                                    expense: expense,
                                    currencyCode: currencyCode,
                                    category: categoryStore.category(for: expense)
                                )
                                .padding(.vertical, InpensoTheme.Space.xs)
                            }
                            .buttonStyle(.plain)

                            if index < viewModel.recentExpenses(limit: 5).count - 1 {
                                Divider().opacity(0.28)
                            }
                        }
                    }
                }
            }
        }
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
