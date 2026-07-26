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
            let daysFromMonday = (weekday + 5) % 7 // Monday-start week
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
        let interval = period.dateInterval(relativeTo: date)
        return expenses
            .filter { $0.type == .expense && interval.contains($0.date) }
            .reduce(0) { $0 + $1.price }
    }

    static func income(from expenses: [Expense], period: SpendingPeriod, date: Date = Date()) -> Double {
        let interval = period.dateInterval(relativeTo: date)
        return expenses
            .filter { $0.type == .income && interval.contains($0.date) }
            .reduce(0) { $0 + $1.price }
    }

    static func net(from expenses: [Expense], period: SpendingPeriod, date: Date = Date()) -> Double {
        income(from: expenses, period: period, date: date) - spent(from: expenses, period: period, date: date)
    }

    static func categoryBreakdown(from expenses: [Expense], period: SpendingPeriod, date: Date = Date()) -> [String: Double] {
        let interval = period.dateInterval(relativeTo: date)
        var totals: [String: Double] = [:]
        for expense in expenses where expense.type == .expense && interval.contains(expense.date) {
            totals[expense.categoryID, default: 0] += expense.price
        }
        return totals
    }
}
