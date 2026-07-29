//
//  SubscriptionManagerView.swift
//  iExpense
//
//  Burn-rate view of recurring expenses (Rocket Money-style, no bank sync).
//

import SwiftUI

struct SubscriptionManagerView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var pro: ProEntitlementManager
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel
    @ObservedObject private var service = RecurringTransactionService.shared

    private var currencyCode: String { settingsViewModel.selectedCurrency }

    private var subscriptions: [RecurringTransaction] {
        service.items
            .filter { $0.isActive && $0.type == .expense }
            .sorted {
                AvailableTodayCalculator.monthlyEquivalent(amount: $0.amount, frequency: $0.frequency)
                    >
                    AvailableTodayCalculator.monthlyEquivalent(amount: $1.amount, frequency: $1.frequency)
            }
    }

    private var monthlyBurn: Double {
        subscriptions.reduce(0) {
            $0 + AvailableTodayCalculator.monthlyEquivalent(amount: $1.amount, frequency: $1.frequency)
        }
    }

    private var dueSoon: [RecurringTransaction] {
        let horizon = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return subscriptions.filter { $0.nextDueDate <= horizon }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                    burnCard

                    if !pro.isPro {
                        ProGateBanner(message: "Unlimited subscriptions & due alerts with Pro.") {
                            pro.openPaywall()
                        }
                    }

                    if !dueSoon.isEmpty {
                        section(title: "Due in 7 days") {
                            ForEach(dueSoon) { item in
                                row(item, emphasizeDate: true)
                            }
                        }
                    }

                    section(title: "All subscriptions") {
                        if subscriptions.isEmpty {
                            Text("Add recurring expenses like Netflix or rent to see your monthly burn.")
                                .font(InpensoTheme.body(14))
                                .foregroundStyle(InpensoTheme.muted)
                                .padding(InpensoTheme.Space.md)
                        } else {
                            ForEach(subscriptions) { item in
                                row(item, emphasizeDate: false)
                            }
                        }
                    }

                    NavigationLink {
                        RecurringTransactionsView(expenseViewModel: expenseViewModel)
                    } label: {
                        Text("Manage recurring")
                            .font(InpensoTheme.body(15, weight: .semibold))
                            .foregroundStyle(InpensoTheme.tide)
                            .frame(maxWidth: .infinity)
                            .padding(InpensoTheme.Space.md)
                            .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, InpensoTheme.Space.screen)
                .padding(.vertical, InpensoTheme.Space.md)
                .padding(.bottom, InpensoTheme.Space.bottomClearance)
            }
        }
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var burnCard: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text("Monthly burn")
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
            Text(monthlyBurn, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(36))
                .foregroundStyle(InpensoTheme.expenseTint)
            Text("\(subscriptions.count) active · from your recurring list")
                .font(InpensoTheme.label(12))
                .foregroundStyle(InpensoTheme.slate)
        }
        .padding(InpensoTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text(title)
                .font(InpensoTheme.sectionLabel())
                .foregroundStyle(InpensoTheme.muted)
            VStack(spacing: 0) {
                content()
            }
            .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
        }
    }

    private func row(_ item: RecurringTransaction, emphasizeDate: Bool) -> some View {
        let category = categoryStore.category(for: item.categoryID)
        let monthly = AvailableTodayCalculator.monthlyEquivalent(amount: item.amount, frequency: item.frequency)
        return HStack(spacing: InpensoTheme.Space.sm) {
            Image(systemName: category.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(category.color)
                .frame(width: 40, height: 40)
                .background(category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Text(emphasizeDate
                     ? "Due \(item.nextDueDate.formatted(.dateTime.month(.abbreviated).day())) · \(item.frequency.displayName)"
                     : item.frequency.displayName)
                    .font(InpensoTheme.label(12))
                    .foregroundStyle(InpensoTheme.muted)
            }
            Spacer()
            Text(monthly, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(14))
                .foregroundStyle(InpensoTheme.slate)
        }
        .padding(.horizontal, InpensoTheme.Space.md)
        .padding(.vertical, 12)
    }
}
