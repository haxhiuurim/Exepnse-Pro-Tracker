//
//  HomeView.swift
//  iExpense
//
//  Final banking home — Obsidian spent hero + jade money snapshot.
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

    @State private var dateSelection = LedgerDateSelection(mode: .day)
    @State private var selectedExpenseToEdit: Expense?
    @State private var showReceiptScan = false
    @State private var showInsights = false
    @State private var showAvailableToday = false
    @State private var showAccounts = false
    @State private var showSubscriptions = false
    @State private var appeared = false

    @ObservedObject private var premiumStore = PremiumDataStore.shared
    @ObservedObject private var onboarding = OnboardingStore.shared
    @ObservedObject private var recurring = RecurringTransactionService.shared
    @ObservedObject private var tripShortcuts = TripShortcutsStore.shared
    @State private var openTripID: Int?

    private var currencyCode: String { settingsViewModel.selectedCurrency }
    private var interval: DateInterval { dateSelection.interval() }

    private var periodSpent: Double {
        PeriodTotals.spent(from: viewModel.expenses, interval: interval)
    }

    private var periodIncome: Double {
        PeriodTotals.income(from: viewModel.expenses, interval: interval)
    }

    private var periodNet: Double {
        PeriodTotals.net(from: viewModel.expenses, interval: interval)
    }

    private var availableToday: AvailableTodayResult {
        AvailableTodayCalculator.compute(
            expenses: viewModel.expenses,
            recurring: recurring.items,
            monthlyIncomeOverride: onboarding.monthlyIncome,
            monthlySavingsTarget: onboarding.monthlySavingsTarget,
            liquidCash: premiumStore.availableCash
        )
    }

    private var periodTransactions: [Expense] {
        viewModel.expenses
            .filter { !$0.isBalanceAdjustment && interval.contains($0.date) }
            .sorted { $0.date > $1.date }
    }

    private var dayGroups: [(day: Date, title: String, items: [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: periodTransactions) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            (day, Self.dayTitle(day, calendar: calendar), grouped[day] ?? [])
        }
    }

    private var spentLabel: String {
        switch dateSelection.mode {
        case .day:
            return Calendar.current.isDateInToday(dateSelection.anchor) ? "Spent today" : "Spent"
        case .week: return "Spent this week"
        case .month: return "Spent this month"
        case .year: return "Spent this year"
        }
    }

    private var budgetProgress: Double? {
        let budget = analyticsViewModel.currentBudget
        guard budget > 0, isViewingCurrentMonth else { return nil }
        return min(1, analyticsViewModel.totalSpent / budget)
    }

    private var isViewingCurrentMonth: Bool {
        let calendar = Calendar.current
        let now = Date()
        return calendar.component(.month, from: now) == analyticsViewModel.selectedMonth
            && calendar.component(.year, from: now) == analyticsViewModel.selectedYear
    }

    private var showsPaceHint: Bool {
        isViewingCurrentMonth
            && PeriodTotals.spent(from: viewModel.expenses, period: .month) > 0
            && analyticsViewModel.projectedMonthlySpend > 0
    }

    private var hasAccounts: Bool {
        !premiumStore.accounts.isEmpty || abs(premiumStore.availableCash) > 0.001
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        topBar
                            .reveal(appeared, delay: 0)

                        spentBlock
                            .reveal(appeared, delay: 0.04)

                        moneySnapshot
                            .reveal(appeared, delay: 0.08)

                        shortcutsRow
                            .reveal(appeared, delay: 0.12)

                        if !tripShortcuts.shortcuts.isEmpty {
                            tripShortcutsRow
                                .reveal(appeared, delay: 0.14)
                        }

                        feed
                            .reveal(appeared, delay: 0.16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
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
                    .onAppear { OnboardingStore.shared.ensureInsightsPreviewStarted() }
            }
            .navigationDestination(isPresented: $showAvailableToday) {
                AvailableTodaySettingsView()
            }
            .navigationDestination(isPresented: $showAccounts) {
                AccountsNetWorthView()
            }
            .navigationDestination(isPresented: $showSubscriptions) {
                SubscriptionManagerView()
            }
            .navigationDestination(isPresented: Binding(
                get: { openTripID != nil },
                set: { if !$0 { openTripID = nil } }
            )) {
                if let id = openTripID {
                    SharedTripDetailView(tripID: id)
                }
            }
            .onAppear {
                syncAnalytics()
                analyticsViewModel.updateExpenses(viewModel.expenses)
                refreshLiveActivity()
                withAnimation(InpensoTheme.Motion.reveal) { appeared = true }
            }
            .onChange(of: viewModel.expenses) {
                syncAnalytics()
                analyticsViewModel.updateExpenses(viewModel.expenses)
                refreshLiveActivity()
            }
            .onChange(of: dateSelection) { _, _ in
                syncAnalytics()
            }
        }
    }

    // MARK: - Top

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppBrand.name)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                Text(Date(), format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer()

            Button { showReceiptScan = true } label: {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(InpensoTheme.panelFill))
                    .shadow(color: InpensoTheme.ink.opacity(0.06), radius: 8, y: 2)
            }
            .accessibilityLabel("Scan receipt")

            Button { onAddTransaction(.expense) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [InpensoTheme.expenseTint, Color(inpensoHex: "#C9443A")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .shadow(color: InpensoTheme.expenseTint.opacity(0.35), radius: 10, y: 4)
            }
            .accessibilityLabel("Add expense")

            Button { onAddTransaction(.income) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [InpensoTheme.incomeTint, Color(inpensoHex: "#0B7A58")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .shadow(color: InpensoTheme.incomeTint.opacity(0.35), radius: 10, y: 4)
            }
            .accessibilityLabel("Add income")
        }
    }

    // MARK: - Spent hero

    private var spentBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                periodChevron(step: -1)
                Spacer()
                Text(dateSelection.summaryTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                periodChevron(step: 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(spentLabel.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.55))

                    Capsule()
                        .fill(InpensoTheme.glow.opacity(0.35))
                        .frame(width: 6, height: 6)
                }

                Text(periodSpent, format: .currency(code: currencyCode))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 10) {
                metaBadge(title: "Income", value: periodIncome, tint: InpensoTheme.seafoam)
                metaBadge(title: "Net", value: periodNet, tint: periodNet >= 0 ? InpensoTheme.seafoam : InpensoTheme.danger)
            }

            BankingPeriodChips(selection: $dateSelection)

            if showsPaceHint {
                Button { openInsights() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12, weight: .semibold))
                        Text("On track for \(analyticsViewModel.projectedMonthlySpend.formatted(.currency(code: currencyCode)))")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Spacer(minLength: 0)
                        Text("Insights")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BankingHeroBackground())
    }

    private func periodChevron(step: Int) -> some View {
        Button {
            withAnimation(InpensoTheme.Motion.snappy) {
                dateSelection.shift(by: step)
            }
        } label: {
            Image(systemName: step < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(0.12)))
        }
    }

    private func metaBadge(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.48))
            Text(value, format: .currency(code: currencyCode))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Money snapshot

    private var moneySnapshot: some View {
        VStack(spacing: 10) {
            Button { showAvailableToday = true } label: {
                snapshotCard(
                    icon: "sun.max.fill",
                    iconTint: InpensoTheme.tide,
                    title: "Available today",
                    subtitle: availableToday.isConfigured
                        ? "\(availableToday.daysRemainingInMonth)d left this month"
                        : "Set income to personalize",
                    value: availableToday.amount,
                    valueColor: availableToday.amount >= 0 ? InpensoTheme.tide : InpensoTheme.danger
                )
            }
            .buttonStyle(.plain)

            Button { showAccounts = true } label: {
                snapshotCard(
                    icon: "building.columns.fill",
                    iconTint: InpensoTheme.ink,
                    title: "Available cash",
                    subtitle: hasAccounts
                        ? "Net worth \(premiumStore.netWorth.formatted(.currency(code: currencyCode)))"
                        : "Add accounts to track cash",
                    value: premiumStore.availableCash,
                    valueColor: InpensoTheme.ink
                )
            }
            .buttonStyle(.plain)

            if let progress = budgetProgress {
                Button { openInsights() } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "target")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(progress > 0.9 ? InpensoTheme.danger : InpensoTheme.tide)
                                .frame(width: 36, height: 36)
                                .background(
                                    (progress > 0.9 ? InpensoTheme.danger : InpensoTheme.tide).opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Monthly budget")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(InpensoTheme.ink)
                                Text("\(analyticsViewModel.totalSpent.formatted(.currency(code: currencyCode))) of \(analyticsViewModel.currentBudget.formatted(.currency(code: currencyCode)))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(InpensoTheme.muted)
                            }

                            Spacer()

                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(progress > 0.9 ? InpensoTheme.danger : InpensoTheme.tide)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(InpensoTheme.muted.opacity(0.5))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(InpensoTheme.mist)
                                Capsule()
                                    .fill(progress > 0.9 ? InpensoTheme.danger : InpensoTheme.tide)
                                    .frame(width: max(6, geo.size.width * progress))
                            }
                        }
                        .frame(height: 7)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(InpensoTheme.panelFill)
                            .shadow(color: InpensoTheme.ink.opacity(0.05), radius: 12, y: 4)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func snapshotCard(
        icon: String,
        iconTint: Color,
        title: String,
        subtitle: String,
        value: Double,
        valueColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 36, height: 36)
                .background(
                    iconTint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(InpensoTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(value, format: .currency(code: currencyCode))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(InpensoTheme.muted.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .shadow(color: InpensoTheme.ink.opacity(0.05), radius: 12, y: 4)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Shortcuts

    private var shortcutsRow: some View {
        HStack(spacing: 10) {
            shortcutChip(title: "Insights", systemImage: "chart.xyaxis.line", tint: InpensoTheme.tide) {
                openInsights()
            }
            shortcutChip(title: "Bills", systemImage: "creditcard.fill", tint: InpensoTheme.danger) {
                showSubscriptions = true
            }
            shortcutChip(title: "Cash", systemImage: "building.columns.fill", tint: InpensoTheme.ink) {
                showAccounts = true
            }
        }
    }

    private var tripShortcutsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pinned trips")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(InpensoTheme.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tripShortcuts.shortcuts) { trip in
                        Button {
                            openTripID = trip.id
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(InpensoTheme.tide)
                                Text(trip.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(InpensoTheme.ink)
                                    .lineLimit(1)
                                Text(trip.inviteCode)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(InpensoTheme.muted)
                            }
                            .padding(12)
                            .frame(width: 140, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(InpensoTheme.panelFill)
                                    .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 10, y: 3)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func shortcutChip(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(
                        tint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(InpensoTheme.panelFill)
                    .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 10, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feed

    private var feed: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                Spacer()
                Button("Activity") {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToExpensesTab"), object: nil)
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(InpensoTheme.tide)
            }

            if periodTransactions.isEmpty {
                emptyFeed
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(dayGroups, id: \.day) { group in
                        daySection(title: group.title, items: group.items)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private func daySection(title: String, items: [Expense]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(InpensoTheme.muted)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, expense in
                    Button {
                        selectedExpenseToEdit = expense
                    } label: {
                        TransactionRowView(
                            expense: expense,
                            currencyCode: currencyCode,
                            category: categoryStore.category(for: expense),
                            showsDate: false
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider()
                            .overlay(InpensoTheme.hairline)
                            .padding(.leading, 66)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(InpensoTheme.panelFill)
                    .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 10, y: 3)
            )
        }
    }

    private var emptyFeed: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing here yet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(InpensoTheme.ink)
            Text("Tap + to add your first expense for this period.")
                .font(.system(size: 14))
                .foregroundStyle(InpensoTheme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(InpensoTheme.panelFill)
        )
    }

    // MARK: - Helpers

    private func syncAnalytics() {
        let calendar = Calendar.current
        let source: Date
        switch dateSelection.mode {
        case .month, .year:
            source = dateSelection.anchor
        case .day, .week:
            source = Date()
        }
        let month = calendar.component(.month, from: source)
        let year = calendar.component(.year, from: source)
        if analyticsViewModel.selectedMonth != month || analyticsViewModel.selectedYear != year {
            analyticsViewModel.changeMonthYear(month: month, year: year)
        }
    }

    private func refreshLiveActivity() {
        guard pro.isPro else { return }
        SpentTodayLiveActivity.startOrUpdate(
            amount: viewModel.spent(for: .today),
            currencyCode: currencyCode,
            isPro: true
        )
    }

    private func openInsights() {
        if pro.canUseFullInsights || pro.canUseInsightsOverview {
            OnboardingStore.shared.ensureInsightsPreviewStarted()
            showInsights = true
        } else {
            pro.openPaywall(plan: .yearly)
        }
    }

    private static func dayTitle(_ day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
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
