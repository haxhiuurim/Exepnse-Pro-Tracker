//
//  iExpenseWidgetExtension.swift
//  iExpenseWidgetExtension
//
//  Period widgets (today / week / month) with one-tap add.
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

struct ExpenseEntry: TimelineEntry {
    let date: Date
    let period: SpendingPeriod
    let totalSpent: Double
    let totalIncome: Double
    let monthlyBudget: Double
    let todaySpent: Double
    let weekSpent: Double
    let monthSpent: Double
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
            totalIncome: 0,
            monthlyBudget: 1000,
            todaySpent: 24,
            weekSpent: 180,
            monthSpent: 640,
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
    static let hairline = Color(red: 0.843, green: 0.867, blue: 0.918)
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

    // MARK: Small — single period + add

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(AppBrand.name)
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(NorthWidgetColor.ink)
                Spacer()
                Text(entry.period.shortTitle.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(NorthWidgetColor.tide)
            }

            Spacer(minLength: 0)

            Text(entry.totalSpent, format: .currency(code: currencyCode))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(NorthWidgetColor.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(entry.period.spentLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button(intent: OpenQuickAddIntent()) {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .tint(NorthWidgetColor.tide)
        }
        .containerBackground(for: .widget) {
            widgetAtmosphere
        }
    }

    // MARK: Medium — today/week/month + add

    private var mediumWidget: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppBrand.name)
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(NorthWidgetColor.ink)

                Text(entry.totalSpent, format: .currency(code: currencyCode))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(NorthWidgetColor.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(entry.period.displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(intent: OpenQuickAddIntent()) {
                    Label("Add spend", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .tint(NorthWidgetColor.tide)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                periodLine(title: "Today", amount: entry.todaySpent)
                periodLine(title: "Week", amount: entry.weekSpent)
                periodLine(title: "Month", amount: entry.monthSpent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) {
            widgetAtmosphere
        }
    }

    // MARK: Large — periods + templates + budget

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppBrand.name)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundStyle(NorthWidgetColor.ink)
                    Text(entry.period.displayTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(intent: OpenQuickAddIntent()) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(NorthWidgetColor.tide, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text(entry.totalSpent, format: .currency(code: currencyCode))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(NorthWidgetColor.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            HStack(spacing: 8) {
                miniStat(title: "Today", amount: entry.todaySpent)
                miniStat(title: "Week", amount: entry.weekSpent)
                miniStat(title: "Month", amount: entry.monthSpent)
            }

            if entry.monthlyBudget > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.overBudget ? "Over budget" : "Budget left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(entry.overBudget ? NorthWidgetColor.expense : .secondary)
                        Spacer()
                        Text(entry.overBudget ? entry.monthSpent - entry.monthlyBudget : entry.budgetRemaining, format: .currency(code: currencyCode))
                            .font(.caption.weight(.bold))
                    }
                    Gauge(value: entry.budgetProgress) {
                        EmptyView()
                    }
                    .gaugeStyle(.linearCapacity)
                    .tint(entry.overBudget ? NorthWidgetColor.expense : NorthWidgetColor.income)
                }
            }

            if !entry.topTemplates.isEmpty {
                Text("Quick spends")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(entry.topTemplates.prefix(3), id: \.id) { template in
                        Button(intent: AddTemplateExpenseIntent(templateID: template.id.uuidString)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                Text(template.amount, format: .currency(code: currencyCode))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(NorthWidgetColor.mist, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) {
            widgetAtmosphere
        }
    }

    private func periodLine(title: String, amount: Double) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(amount, format: .currency(code: currencyCode))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(NorthWidgetColor.ink)
        }
    }

    private func miniStat(title: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(amount, format: .currency(code: currencyCode))
                .font(.system(size: 13, weight: .bold, design: .rounded))
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
        .configurationDisplayName("Expense Spending")
        .description("See today, week, or month spending — and add a spend with one tap.")
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
        topTemplates: Array(QuickSpendTemplate.starterTemplates.prefix(2))
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
        topTemplates: Array(QuickSpendTemplate.starterTemplates.prefix(2))
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
        topTemplates: Array(QuickSpendTemplate.starterTemplates.prefix(3))
    )
}
