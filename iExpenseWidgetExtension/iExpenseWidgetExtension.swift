//
//  iExpenseWidgetExtension.swift
//  iExpenseWidgetExtension
//
//  North-styled period widgets with expense / income quick actions.
//

import WidgetKit
import SwiftUI
import AppIntents
import Foundation

let appGroupID = "group.com.premiumsolutions.expenses"

func getAppCurrency() -> String {
    let sharedDefaults = UserDefaults(suiteName: appGroupID)
    sharedDefaults?.synchronize()
    if let currency = sharedDefaults?.string(forKey: "selectedCurrency") {
        return currency
    }
    return UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
}

func getMonthlyBudget() -> Double {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupID),
          let budgetsData = sharedDefaults.data(forKey: "budgets"),
          let budgets = try? JSONDecoder().decode([String: Double].self, from: budgetsData) else {
        return 0
    }
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MM-yyyy"
    return budgets[dateFormatter.string(from: Date())] ?? 0
}

struct WidgetHistoryItem: Identifiable {
    let id: UUID
    let title: String
    let amount: Double
    let isIncome: Bool
    let date: Date
}

struct ExpenseEntry: TimelineEntry {
    let date: Date
    let period: SpendingPeriod
    let totalSpent: Double
    let totalIncome: Double
    let monthlyBudget: Double
    let todaySpent: Double
    let weekSpent: Double
    let monthSpent: Double
    let recentItems: [WidgetHistoryItem]
    let topTemplates: [QuickSpendTemplate]

    var netCashflow: Double { totalIncome - totalSpent }

    var budgetRemaining: Double {
        max(0, monthlyBudget - monthSpent)
    }

    var budgetProgress: Double {
        monthlyBudget > 0 ? min(1.0, monthSpent / monthlyBudget) : 0
    }

    var overBudget: Bool {
        monthlyBudget > 0 && monthSpent > monthlyBudget
    }
}

struct ExpenseQuickAddProvider: AppIntentTimelineProvider {
    typealias Intent = QuickAddConfigurationIntent

    func placeholder(in context: Context) -> ExpenseEntry {
        ExpenseEntry(
            date: Date(),
            period: .month,
            totalSpent: 120,
            totalIncome: 2400,
            monthlyBudget: 1000,
            todaySpent: 24,
            weekSpent: 180,
            monthSpent: 640,
            recentItems: [
                WidgetHistoryItem(id: UUID(), title: "Coffee", amount: 4.5, isIncome: false, date: Date()),
                WidgetHistoryItem(id: UUID(), title: "Paycheck", amount: 1200, isIncome: true, date: Date())
            ],
            topTemplates: Array(QuickSpendTemplate.starterTemplates.prefix(2))
        )
    }

    func snapshot(for configuration: QuickAddConfigurationIntent, in context: Context) async -> ExpenseEntry {
        loadEntry(period: configuration.period)
    }

    func timeline(for configuration: QuickAddConfigurationIntent, in context: Context) async -> Timeline<ExpenseEntry> {
        let entry = loadEntry(period: configuration.period)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
    }

    private func loadEntry(period: SpendingPeriod) -> ExpenseEntry {
        let expenses = StorageService.loadExpenses()
        let templates = StorageService.loadQuickTemplates()
            .sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }

        let interval = period.dateInterval(relativeTo: Date())
        let recent = expenses
            .filter { interval.contains($0.date) }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map {
                WidgetHistoryItem(
                    id: $0.id,
                    title: $0.title.isEmpty ? ($0.type == .income ? "Income" : "Expense") : $0.title,
                    amount: $0.price,
                    isIncome: $0.type == .income,
                    date: $0.date
                )
            }

        StorageService.saveWidgetPeriod(period)

        return ExpenseEntry(
            date: Date(),
            period: period,
            totalSpent: PeriodTotals.spent(from: expenses, period: period),
            totalIncome: PeriodTotals.income(from: expenses, period: period),
            monthlyBudget: getMonthlyBudget(),
            todaySpent: PeriodTotals.spent(from: expenses, period: .today),
            weekSpent: PeriodTotals.spent(from: expenses, period: .week),
            monthSpent: PeriodTotals.spent(from: expenses, period: .month),
            recentItems: Array(recent),
            topTemplates: Array(templates.prefix(3))
        )
    }
}

// MARK: - Views

private enum NorthWidgetColor {
    static let ink = Color(red: 0.043, green: 0.106, blue: 0.200)
    static let tide = Color(red: 0.231, green: 0.431, blue: 0.961)
    static let expense = Color(red: 0.941, green: 0.263, blue: 0.365)
    static let income = Color(red: 0.071, green: 0.725, blue: 0.506)
    static let foam = Color(red: 0.933, green: 0.945, blue: 0.965)
    static let mist = Color(red: 0.894, green: 0.918, blue: 0.953)
    static let muted = Color(red: 0.420, green: 0.475, blue: 0.565)
}

struct iExpenseWidgetEntryView: View {
    var entry: ExpenseEntry
    @Environment(\.widgetFamily) var family
    private let currencyCode = getAppCurrency()

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }

    // MARK: Small

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppBrand.name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(NorthWidgetColor.ink)
                Spacer()
                Text(entry.period.shortTitle.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(NorthWidgetColor.tide)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(NorthWidgetColor.tide.opacity(0.12), in: Capsule())
            }

            Spacer(minLength: 0)

            Text(entry.totalSpent, format: .currency(code: currencyCode))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NorthWidgetColor.ink)
                .minimumScaleFactor(0.55)
                .lineLimit(1)

            Text(entry.period.spentLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NorthWidgetColor.muted)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Button(intent: OpenQuickAddIntent(transactionType: "expense")) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .tint(NorthWidgetColor.expense)

                Button(intent: OpenQuickAddIntent(transactionType: "income")) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .tint(NorthWidgetColor.income)
            }
        }
        .containerBackground(for: .widget) {
            widgetAtmosphere
        }
    }

    // MARK: Medium

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppBrand.name)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(NorthWidgetColor.ink)
                    Text(entry.period.displayTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NorthWidgetColor.muted)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button(intent: OpenQuickAddIntent(transactionType: "expense")) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(NorthWidgetColor.expense)
                    }
                    .buttonStyle(.plain)

                    Button(intent: OpenQuickAddIntent(transactionType: "income")) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(NorthWidgetColor.income)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                summaryBlock(title: "Spent", amount: entry.totalSpent, tint: NorthWidgetColor.expense)
                summaryBlock(title: "Income", amount: entry.totalIncome, tint: NorthWidgetColor.income)
                summaryBlock(
                    title: "Net",
                    amount: entry.netCashflow,
                    tint: entry.netCashflow >= 0 ? NorthWidgetColor.income : NorthWidgetColor.expense
                )
            }
        }
        .containerBackground(for: .widget) {
            widgetAtmosphere
        }
    }

    // MARK: Large — summary + history

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppBrand.name)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(NorthWidgetColor.ink)
                    Text(entry.period.displayTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NorthWidgetColor.muted)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(intent: OpenQuickAddIntent(transactionType: "expense")) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(NorthWidgetColor.expense)
                    }
                    .buttonStyle(.plain)

                    Button(intent: OpenQuickAddIntent(transactionType: "income")) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(NorthWidgetColor.income)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                summaryBlock(title: "Spent", amount: entry.totalSpent, tint: NorthWidgetColor.expense)
                summaryBlock(title: "Income", amount: entry.totalIncome, tint: NorthWidgetColor.income)
                summaryBlock(
                    title: "Net",
                    amount: entry.netCashflow,
                    tint: entry.netCashflow >= 0 ? NorthWidgetColor.income : NorthWidgetColor.expense
                )
            }

            if entry.monthlyBudget > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.overBudget ? "Over budget" : "Budget left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(entry.overBudget ? NorthWidgetColor.expense : NorthWidgetColor.muted)
                        Spacer()
                        Text(
                            entry.overBudget ? entry.monthSpent - entry.monthlyBudget : entry.budgetRemaining,
                            format: .currency(code: currencyCode)
                        )
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    Gauge(value: entry.budgetProgress) { EmptyView() }
                        .gaugeStyle(.linearCapacity)
                        .tint(entry.overBudget ? NorthWidgetColor.expense : NorthWidgetColor.income)
                }
            }

            Text("Recent")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NorthWidgetColor.muted)
                .textCase(.uppercase)

            if entry.recentItems.isEmpty {
                Text("No transactions in this period")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NorthWidgetColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(NorthWidgetColor.mist, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entry.recentItems.enumerated()), id: \.element.id) { index, item in
                        HStack {
                            Circle()
                                .fill(item.isIncome ? NorthWidgetColor.income.opacity(0.15) : NorthWidgetColor.expense.opacity(0.15))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: item.isIncome ? "arrow.down.left" : "arrow.up.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(item.isIncome ? NorthWidgetColor.income : NorthWidgetColor.expense)
                                )

                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(NorthWidgetColor.ink)
                                .lineLimit(1)

                            Spacer()

                            Text(item.isIncome ? item.amount : -item.amount, format: .currency(code: currencyCode))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(item.isIncome ? NorthWidgetColor.income : NorthWidgetColor.expense)
                        }
                        .padding(.vertical, 6)

                        if index < entry.recentItems.count - 1 {
                            Divider().opacity(0.35)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(NorthWidgetColor.mist, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) {
            widgetAtmosphere
        }
    }

    private func summaryBlock(title: String, amount: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NorthWidgetColor.muted)
            Text(amount, format: .currency(code: currencyCode))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(NorthWidgetColor.mist, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var widgetAtmosphere: some View {
        LinearGradient(
            colors: [NorthWidgetColor.foam, Color(red: 0.910, green: 0.929, blue: 0.965)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct iExpenseWidgetExtension: Widget {
    let kind: String = "iExpenseWidgetExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuickAddConfigurationIntent.self, provider: ExpenseQuickAddProvider()) { entry in
            iExpenseWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("Expense")
        .description("Summary, history, and quick add for expense or income.")
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    iExpenseWidgetExtension()
} timeline: {
    ExpenseEntry(
        date: .now,
        period: .today,
        totalSpent: 42.50,
        totalIncome: 0,
        monthlyBudget: 1200,
        todaySpent: 42.50,
        weekSpent: 210,
        monthSpent: 780,
        recentItems: [],
        topTemplates: []
    )
}

#Preview(as: .systemMedium) {
    iExpenseWidgetExtension()
} timeline: {
    ExpenseEntry(
        date: .now,
        period: .week,
        totalSpent: 210.00,
        totalIncome: 500,
        monthlyBudget: 1200,
        todaySpent: 42.50,
        weekSpent: 210,
        monthSpent: 780,
        recentItems: [],
        topTemplates: []
    )
}

#Preview(as: .systemLarge) {
    iExpenseWidgetExtension()
} timeline: {
    ExpenseEntry(
        date: .now,
        period: .month,
        totalSpent: 780.50,
        totalIncome: 2400,
        monthlyBudget: 1200,
        todaySpent: 42.50,
        weekSpent: 210,
        monthSpent: 780.50,
        recentItems: [
            WidgetHistoryItem(id: UUID(), title: "Groceries", amount: 64, isIncome: false, date: .now),
            WidgetHistoryItem(id: UUID(), title: "Salary", amount: 2400, isIncome: true, date: .now)
        ],
        topTemplates: []
    )
}
