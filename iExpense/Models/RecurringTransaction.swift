//
//  RecurringTransaction.swift
//  iExpense
//

import Foundation

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

struct RecurringTransaction: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var amount: Double
    var categoryID: String
    var category: Category
    var type: TransactionType
    var frequency: RecurrenceFrequency
    var startDate: Date
    var nextDueDate: Date
    var endDate: Date?
    var isActive: Bool
    var notes: String?
    var lastGeneratedDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        categoryID: String,
        category: Category = .others,
        type: TransactionType = .expense,
        frequency: RecurrenceFrequency = .monthly,
        startDate: Date = Date(),
        nextDueDate: Date? = nil,
        endDate: Date? = nil,
        isActive: Bool = true,
        notes: String? = nil,
        lastGeneratedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.categoryID = categoryID
        self.category = category
        self.type = type
        self.frequency = frequency
        self.startDate = startDate
        self.nextDueDate = nextDueDate ?? startDate
        self.endDate = endDate
        self.isActive = isActive
        self.notes = notes
        self.lastGeneratedDate = lastGeneratedDate
    }

    func makeExpense(on date: Date) -> Expense {
        Expense(
            title: title,
            price: amount,
            date: date,
            category: category,
            type: type,
            categoryID: categoryID,
            notes: notes.map { "Recurring · \($0)" } ?? "Recurring · \(frequency.displayName)"
        )
    }
}
