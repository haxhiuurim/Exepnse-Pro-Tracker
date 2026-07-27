//
//  HomeView.swift
//  iExpense
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

    @State private var dateSelection = LedgerDateSelection()
    @State private var selectedExpenseToEdit: Expense?
    @State private var showReceiptScan = false
    @State private var showInsights = false
    @ObservedObject private var premiumStore = PremiumDataStore.shared

    private var currencyCode: String { settingsViewModel.selectedCurrency }
    private var interval: DateInterval { dateSelection.interval() }
    private var periodSpent: Double { PeriodTotals.spent(from: viewModel.expenses, interval: interval) }
    private var periodIncome: Double { PeriodTotals.income(from: viewModel.expenses, interval: interval) }
    private var periodNet: Double { PeriodTotals.net(from: viewModel.expenses, interval: interval) }

    private var topCategories: [(String, Double)] {
        PeriodTotals.categoryBreakdown(from: viewModel.expenses, interval: interval)
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { ($0.key, $0.value) }
    }

    private var recent: [Expense] {
        viewModel.expenses
            .filter { interval.contains($0.date) }
            .sorted { $0.date > $1.date }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                        brandHeader
                        if !pro.isPro {
                            proUpsell
                        }
                        heroCard
                        if abs(premiumStore.netWorth) > 0.001 || !premiumStore.accounts.isEmpty {
                            accountsStrip
                        }
                        if dateSelection.mode == .month, analyticsViewModel.currentBudget > 0,
                           Calendar.current.isDate(dateSelection.anchor, equalTo: Date(), toGranularity: .month) {
                            budgetStrip
                        }
                        if !topCategories.isEmpty {
                            categoriesSection
                        }
                        recentSection
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, InpensoTheme.Space.xxl)
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

    // MARK: - Header

    private var brandHeader: some View {
        HStack(alignment: .center, spacing: InpensoTheme.Space.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppBrand.name)
                    .font(InpensoTheme.brandFont(28, weight: .heavy))
                    .foregroundStyle(InpensoTheme.ink)
                Text(dateSelection.summaryTitle)
                    .font(InpensoTheme.label(13))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: 8)

            headerIconButton("minus.circle.fill", tint: InpensoTheme.expenseTint, label: "Add expense") {
                onAddTransaction(.expense)
            }
            headerIconButton("plus.circle.fill", tint: InpensoTheme.incomeTint, label: "Add income") {
                onAddTransaction(.income)
            }
            headerIconButton("doc.text.viewfinder", tint: InpensoTheme.ink, label: "Scan receipt") {
                showReceiptScan = true
            }
        }
    }

    private func headerIconButton(_ systemImage: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(InpensoTheme.panelFill)
                        .shadow(color: InpensoTheme.ink.opacity(0.06), radius: 8, y: 2)
                )
        }
        .accessibilityLabel(label)
    }

    private var proUpsell: some View {
        Button {
            pro.openPaywall(plan: .yearly)
        } label: {
            HStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(InpensoTheme.tide)
                    .frame(width: 36, height: 36)
                    .background(
                        InpensoTheme.tide.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("You're on Free")
                        .font(InpensoTheme.body(15, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("Upgrade for OCR, shortcuts, categories & more")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                }
                Spacer()
                Text("Pro")
                    .font(InpensoTheme.label(13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                            .fill(InpensoTheme.tide)
                    )
            }
            .padding(InpensoTheme.Space.md)
            .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            rangeModePicker

            HStack {
                Button {
                    dateSelection.shift(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(InpensoTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(InpensoTheme.mist, in: Circle())
                }

                Spacer()

                Text(dateSelection.summaryTitle)
                    .font(InpensoTheme.label(14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button {
                    dateSelection.shift(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(InpensoTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(InpensoTheme.mist, in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(dateSelection.spentLabel)
                    .font(InpensoTheme.label(13, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
                Text(periodSpent, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(40))
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
        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
    }

    private var rangeModePicker: some View {
        HStack(spacing: 0) {
            ForEach(LedgerRangeMode.homeModes) { mode in
                let selected = dateSelection.mode == mode
                Button {
                    HapticFeedback.selection()
                    withAnimation(InpensoTheme.Motion.snappy) {
                        dateSelection.mode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(InpensoTheme.label(13, weight: .bold))
                        .foregroundStyle(selected ? .white : InpensoTheme.slate)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                .fill(selected ? InpensoTheme.ink : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                .fill(InpensoTheme.mist)
        )
    }

    private var accountsStrip: some View {
        NavigationLink {
            AccountsNetWorthView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accounts")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                    Text(premiumStore.netWorth, format: .currency(code: currencyCode))
                        .font(InpensoTheme.displayAmount(20))
                        .foregroundStyle(premiumStore.netWorth >= 0 ? InpensoTheme.ink : InpensoTheme.expenseTint)
                }
                Spacer()
                Text("\(premiumStore.accounts.count) accounts")
                    .font(InpensoTheme.label(12, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(InpensoTheme.muted.opacity(0.6))
            }
            .padding(InpensoTheme.Space.md)
            .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
        }
        .buttonStyle(.plain)
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
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Top categories", actionTitle: "Insights") {
                if pro.isPro {
                    showInsights = true
                } else {
                    pro.openPaywall(plan: .yearly)
                }
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
                    .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Recent", actionTitle: "See all") {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToExpensesTab"), object: nil)
            }

            if recent.isEmpty {
                SurfacePanel(padding: InpensoTheme.Space.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nothing in this range")
                            .font(InpensoTheme.body(17, weight: .bold))
                            .foregroundStyle(InpensoTheme.ink)
                        Text("Add an expense or income, or pick another date.")
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
                .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
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
