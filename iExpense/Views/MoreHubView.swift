//
//  MoreHubView.swift
//  iExpense
//
//  Banking-aligned hub: Money · Plan · Tools · App
//

import SwiftUI

struct MoreHubView: View {
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    @ObservedObject var expenseViewModel: ExpenseViewModel

    @EnvironmentObject private var pro: ProEntitlementManager
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    @ObservedObject private var premiumStore = PremiumDataStore.shared
    @ObservedObject private var onboarding = OnboardingStore.shared
    @ObservedObject private var recurring = RecurringTransactionService.shared
    @ObservedObject private var auth = AuthSession.shared

    private var currencyCode: String { settingsViewModel.selectedCurrency }

    private var availableToday: AvailableTodayResult {
        AvailableTodayCalculator.compute(
            expenses: expenseViewModel.expenses,
            recurring: recurring.items,
            monthlyIncomeOverride: onboarding.monthlyIncome,
            monthlySavingsTarget: onboarding.monthlySavingsTarget,
            liquidCash: premiumStore.availableCash
        )
    }

    private var subscriptionBurn: Double {
        recurring.items
            .filter { $0.isActive && $0.type == .expense }
            .reduce(0.0) {
                $0 + AvailableTodayCalculator.monthlyEquivalent(amount: $1.amount, frequency: $1.frequency)
            }
    }

    private var debtRemaining: Double {
        premiumStore.debts.reduce(0) { $0 + $1.remaining }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("More")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(InpensoTheme.ink)

                        if !pro.isPro {
                            proBanner
                        }

                        moneyOverviewCard

                        hubGroup(title: "Understand") {
                            hubRow(
                                "Insights",
                                insightsSubtitle,
                                "chart.xyaxis.line",
                                InpensoTheme.tide,
                                trailing: analyticsViewModel.totalSpent > 0
                                    ? analyticsViewModel.totalSpent.formatted(.currency(code: currencyCode))
                                    : nil
                            ) {
                                AnalyticsView(analyticsViewModel: analyticsViewModel)
                                    .onAppear { OnboardingStore.shared.ensureInsightsPreviewStarted() }
                            }
                        }

                        hubGroup(title: "Money") {
                            hubRow(
                                "Available Today",
                                availableToday.isConfigured ? "Safe daily spend" : "Set income to personalize",
                                "sun.max",
                                InpensoTheme.tide,
                                trailing: availableToday.amount.formatted(.currency(code: currencyCode))
                            ) {
                                AvailableTodaySettingsView()
                            }
                            hubRow(
                                "Accounts",
                                "Cash & net worth",
                                "building.columns",
                                InpensoTheme.ink,
                                trailing: premiumStore.availableCash.formatted(.currency(code: currencyCode))
                            ) {
                                AccountsNetWorthView()
                            }
                            hubRow(
                                "Debt & EMI",
                                "Payoff plans · no bank link",
                                "creditcard.fill",
                                InpensoTheme.expenseTint,
                                trailing: debtRemaining > 0
                                    ? debtRemaining.formatted(.currency(code: currencyCode))
                                    : nil
                            ) {
                                DebtTrackerView()
                            }
                            hubRow("Goals", "Targets & envelopes", "target", InpensoTheme.incomeTint) {
                                SavingsGoalsView()
                            }
                        }

                        hubGroup(title: "Plan") {
                            hubRow(
                                "Subscriptions",
                                "Monthly burn & due soon",
                                "creditcard",
                                InpensoTheme.expenseTint,
                                trailing: subscriptionBurn > 0
                                    ? subscriptionBurn.formatted(.currency(code: currencyCode))
                                    : nil
                            ) {
                                SubscriptionManagerView()
                            }
                            hubRow("Recurring", "Bills, income & cadence", "arrow.triangle.2.circlepath", InpensoTheme.ink) {
                                RecurringTransactionsView(expenseViewModel: expenseViewModel)
                            }
                            if pro.isPro {
                                hubRow("Upcoming", "Next 30 days", "calendar", InpensoTheme.ink) {
                                    UpcomingRecurringCalendarView()
                                }
                            }
                        }

                        hubGroup(title: "Tools") {
                            hubRow("Merchant rules", "Starter free · custom Pro", "bolt.horizontal", InpensoTheme.tide) {
                                MerchantRulesView()
                            }
                            hubRow(
                                "Categories",
                                pro.isPro ? "Order, hide, create" : "Customize with Pro",
                                "square.grid.2x2",
                                InpensoTheme.ink
                            ) {
                                CategoryManagementView()
                            }
                        }

                        hubGroup(title: "App") {
                            hubRow(
                                auth.isLoggedIn
                                    ? (auth.displayName.isEmpty ? "Account" : auth.displayName)
                                    : "Sign in",
                                auth.isLoggedIn
                                    ? (auth.email.isEmpty ? "Synced · Trips unlocked" : auth.email)
                                    : "Backup & Trips require an account",
                                "person.crop.circle",
                                InpensoTheme.tide,
                                trailing: auth.isLoggedIn ? "Signed in" : nil
                            ) {
                                AccountHubView()
                            }
                            shareAppRow
                            hubRow("Settings", "Currency, lock, data, Pro", "gearshape", InpensoTheme.slate) {
                                SettingsView()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, InpensoTheme.Space.bottomClearance)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                analyticsViewModel.updateExpenses(expenseViewModel.expenses)
            }
        }
    }

    private var moneyOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AT A GLANCE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.5))

            HStack(alignment: .top, spacing: 0) {
                glanceStat(
                    title: "Available today",
                    value: availableToday.amount,
                    tint: InpensoTheme.seafoam
                )
                glanceDivider
                glanceStat(
                    title: "Cash",
                    value: premiumStore.availableCash,
                    tint: .white
                )
                glanceDivider
                glanceStat(
                    title: "Month spent",
                    value: analyticsViewModel.totalSpent,
                    tint: .white
                )
            }
        }
        .padding(18)
        .background(BankingHeroBackground(radius: 24))
    }

    private var glanceDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 40)
            .padding(.horizontal, 8)
    }

    private func glanceStat(title: String, value: Double, tint: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value, format: .currency(code: currencyCode))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var proBanner: some View {
        Button {
            pro.openPaywall(plan: .yearly)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppBrand.proName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("OCR · Insights · sync · \(ProPlan.yearly.displayPrice)/yr")
                        .font(.system(size: 12))
                        .foregroundStyle(InpensoTheme.muted)
                }
                Spacer()
                Text("Upgrade")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [InpensoTheme.tide, Color(inpensoHex: "#0B7A58")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
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

    private var shareAppRow: some View {
        Button {
            let url = RemoteConfigService.shared.config.appStoreURL
            let text = "Track spending with \(AppBrand.name): \(url)"
            let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(activity, animated: true)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
                    .frame(width: 34, height: 34)
                    .background(
                        InpensoTheme.tide.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share app")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("Invite friends via App Store link")
                        .font(.system(size: 12))
                        .foregroundStyle(InpensoTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var insightsSubtitle: String {
        if pro.isPro { return "Charts, trends, budgets" }
        if OnboardingStore.shared.insightsPreviewActive {
            return "Preview · \(OnboardingStore.shared.insightsPreviewDaysRemaining)d left"
        }
        return "Overview free · deeper with Pro"
    }

    private func hubGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(InpensoTheme.muted)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func hubRow<Destination: View>(
        _ title: String,
        _ subtitle: String,
        _ systemImage: String,
        _ tint: Color,
        trailing: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(
                        tint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(InpensoTheme.muted)
                }
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(InpensoTheme.slate)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(InpensoTheme.muted.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
