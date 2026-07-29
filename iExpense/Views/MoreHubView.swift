//
//  MoreHubView.swift
//  iExpense
//
//  North More hub — tools & settings for the new app shell.
//

import SwiftUI

struct MoreHubView: View {
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    @ObservedObject var expenseViewModel: ExpenseViewModel

    @EnvironmentObject private var pro: ProEntitlementManager

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                        Text("More")
                            .font(InpensoTheme.brandFont(32, weight: .heavy))
                            .foregroundStyle(InpensoTheme.ink)

                        if !pro.isPro {
                            proBanner
                        }

                        hubGroup(title: "Understand") {
                            hubRow("Insights", insightsSubtitle, "chart.xyaxis.line", InpensoTheme.tide) {
                                AnalyticsView(analyticsViewModel: analyticsViewModel)
                                    .onAppear {
                                        OnboardingStore.shared.ensureInsightsPreviewStarted()
                                    }
                            }
                        }

                        hubGroup(title: "Plan") {
                            hubRow("Available Today", "Income, bills & safe spend", "sun.max", InpensoTheme.tide) {
                                AvailableTodaySettingsView()
                            }
                            hubRow("Subscriptions", "Monthly burn & due soon", "creditcard", InpensoTheme.expenseTint) {
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
                            hubRow("Goals", "Targets & envelopes", "target", InpensoTheme.incomeTint) {
                                SavingsGoalsView()
                            }
                            hubRow("Debt & EMI", "Payoff plans · no bank link", "creditcard.fill", InpensoTheme.expenseTint) {
                                DebtTrackerView()
                            }
                            hubRow("Accounts", "Balances & net worth", "building.columns", InpensoTheme.ink) {
                                AccountsNetWorthView()
                            }
                        }

                        hubGroup(title: "Automate") {
                            hubRow("Merchant rules", "Starter rules free · custom Pro", "bolt.horizontal", InpensoTheme.tide) {
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
                            hubRow("Settings", "Currency, lock, data, Pro", "gearshape", InpensoTheme.slate) {
                                SettingsView()
                            }
                        }
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, InpensoTheme.Space.bottomClearance)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var proBanner: some View {
        Button {
            pro.openPaywall(plan: .yearly)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppBrand.proName)
                        .font(InpensoTheme.body(16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("OCR · Insights · sync · unlimited tools · \(ProPlan.yearly.displayPrice)/yr")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Text("Upgrade")
                    .font(InpensoTheme.label(13, weight: .bold))
                    .foregroundStyle(InpensoTheme.tide)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white))
            }
            .padding(InpensoTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [InpensoTheme.ink, InpensoTheme.inkSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var insightsSubtitle: String {
        if pro.isPro {
            return "Charts, trends, budgets"
        }
        if OnboardingStore.shared.insightsPreviewActive {
            return "Preview · \(OnboardingStore.shared.insightsPreviewDaysRemaining)d left"
        }
        return "Overview free · deeper Insights with Pro"
    }

    private func hubGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text(title)
                .font(InpensoTheme.sectionLabel())
                .foregroundStyle(InpensoTheme.muted)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .fill(InpensoTheme.panelFill)
                    .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 12, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous))
        }
    }

    private func hubRow<Destination: View>(
        _ title: String,
        _ subtitle: String,
        _ systemImage: String,
        _ tint: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(
                        tint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(InpensoTheme.body(16, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                    Text(subtitle)
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(.horizontal, InpensoTheme.Space.md)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func hubActionRow(
        _ title: String,
        _ subtitle: String,
        _ systemImage: String,
        _ tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(
                        tint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(InpensoTheme.body(16, weight: .semibold))
                            .foregroundStyle(InpensoTheme.ink)
                        Text("PRO")
                            .font(InpensoTheme.label(9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(InpensoTheme.tide, in: Capsule())
                    }
                    Text(subtitle)
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(.horizontal, InpensoTheme.Space.md)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
