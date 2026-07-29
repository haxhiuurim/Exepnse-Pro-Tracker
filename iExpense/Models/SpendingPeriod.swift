//
//  SpendingPeriod.swift
//  iExpense
//

import Foundation
import AppIntents

enum SpendingPeriod: String, CaseIterable, Codable, Identifiable, AppEnum {
    case today
    case week
    case month

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }

    var displayTitle: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        }
    }

    var spentLabel: String {
        switch self {
        case .today: return "spent today"
        case .week: return "spent this week"
        case .month: return "spent this month"
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Spending Period"

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .today: "Today",
        .week: "This Week",
        .month: "This Month"
    ]

    func dateInterval(relativeTo date: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let startOfDay = calendar.startOfDay(for: date)
        switch self {
        case .today:
            let end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            return DateInterval(start: startOfDay, end: end)
        case .week:
            let weekday = calendar.component(.weekday, from: startOfDay)
            let daysFromMonday = (weekday + 5) % 7
            let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? date
            return DateInterval(start: weekStart, end: weekEnd)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: startOfDay)
            let monthStart = calendar.date(from: comps) ?? startOfDay
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? date
            return DateInterval(start: monthStart, end: monthEnd)
        }
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        dateInterval(calendar: calendar).contains(date)
    }
}

enum PeriodTotals {
    static func spent(from expenses: [Expense], period: SpendingPeriod, date: Date = Date()) -> Double {
        spent(from: expenses, interval: period.dateInterval(relativeTo: date))
    }

    static func income(from expenses: [Expense], period: SpendingPeriod, date: Date = Date()) -> Double {
        income(from: expenses, interval: period.dateInterval(relativeTo: date))
    }

    static func net(from expenses: [Expense], period: SpendingPeriod, date: Date = Date()) -> Double {
        net(from: expenses, interval: period.dateInterval(relativeTo: date))
    }

    static func categoryBreakdown(from expenses: [Expense], period: SpendingPeriod, date: Date = Date()) -> [String: Double] {
        categoryBreakdown(from: expenses, interval: period.dateInterval(relativeTo: date))
    }

    static func spent(from expenses: [Expense], interval: DateInterval) -> Double {
        expenses
            .filter { $0.type == .expense && interval.contains($0.date) && !$0.isBalanceAdjustment }
            .reduce(0) { $0 + $1.homeAmount }
    }

    static func income(from expenses: [Expense], interval: DateInterval) -> Double {
        expenses
            .filter { $0.type == .income && interval.contains($0.date) && !$0.isBalanceAdjustment }
            .reduce(0) { $0 + $1.homeAmount }
    }

    static func net(from expenses: [Expense], interval: DateInterval) -> Double {
        income(from: expenses, interval: interval) - spent(from: expenses, interval: interval)
    }

    static func categoryBreakdown(from expenses: [Expense], interval: DateInterval) -> [String: Double] {
        var totals: [String: Double] = [:]
        for expense in expenses where expense.type == .expense && interval.contains(expense.date) && !expense.isBalanceAdjustment {
            totals[expense.categoryID, default: 0] += expense.homeAmount
        }
        return totals
    }
}

// MARK: - Home / Activity date filters

enum LedgerRangeMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    /// Home only uses day/week/month
    static var homeModes: [LedgerRangeMode] { [.day, .week, .month] }
}

struct LedgerDateSelection: Equatable {
    var mode: LedgerRangeMode = .day
    var anchor: Date = Date()

    func interval(calendar: Calendar = .current) -> DateInterval {
        let startOfDay = calendar.startOfDay(for: anchor)
        switch mode {
        case .day:
            let end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? anchor
            return DateInterval(start: startOfDay, end: end)
        case .week:
            return SpendingPeriod.week.dateInterval(relativeTo: anchor, calendar: calendar)
        case .month:
            return SpendingPeriod.month.dateInterval(relativeTo: anchor, calendar: calendar)
        case .year:
            let year = calendar.component(.year, from: startOfDay)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? startOfDay
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? startOfDay
            return DateInterval(start: start, end: end)
        }
    }

    var spentLabel: String {
        switch mode {
        case .day:
            if Calendar.current.isDateInToday(anchor) { return "spent today" }
            return "spent \(anchor.formatted(.dateTime.month(.abbreviated).day()))"
        case .week:
            let interval = interval()
            let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
            let end = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "spent \(start)–\(end.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return "spent \(anchor.formatted(.dateTime.month(.wide).year()))"
        case .year:
            return "spent \(anchor.formatted(.dateTime.year()))"
        }
    }

    var summaryTitle: String {
        switch mode {
        case .day:
            if Calendar.current.isDateInToday(anchor) { return "Today" }
            return anchor.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .week:
            let interval = interval()
            let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
            let end = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "\(start) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return anchor.formatted(.dateTime.month(.wide).year())
        case .year:
            return anchor.formatted(.dateTime.year())
        }
    }

    mutating func shift(by steps: Int, calendar: Calendar = .current) {
        switch mode {
        case .day:
            anchor = calendar.date(byAdding: .day, value: steps, to: anchor) ?? anchor
        case .week:
            anchor = calendar.date(byAdding: .weekOfYear, value: steps, to: anchor) ?? anchor
        case .month:
            anchor = calendar.date(byAdding: .month, value: steps, to: anchor) ?? anchor
        case .year:
            anchor = calendar.date(byAdding: .year, value: steps, to: anchor) ?? anchor
        }
    }
}

/// Back-compat aliases used by HomeView
typealias HomeRangeMode = LedgerRangeMode
typealias HomeDateSelection = LedgerDateSelection
