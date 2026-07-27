//
//  RecurringTransaction.swift
//  iExpense
//

import Foundation

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case daily
    case every3Days
    case weekly
    case every2Weeks
    case every3Weeks
    case every4Weeks
    case monthly
    case monthlyFirst
    case yearly

    /// Legacy alias kept for decoding older saves
    case biweekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Every day"
        case .every3Days: return "Every 3 days"
        case .weekly: return "Every week"
        case .every2Weeks, .biweekly: return "Every 2 weeks"
        case .every3Weeks: return "Every 3 weeks"
        case .every4Weeks: return "Every 4 weeks"
        case .monthly: return "Every month"
        case .monthlyFirst: return "1st of each month"
        case .yearly: return "Every year"
        }
    }

    /// Frequencies shown in the editor (excludes legacy duplicate)
    static var selectableCases: [RecurrenceFrequency] {
        [.daily, .every3Days, .weekly, .every2Weeks, .every3Weeks, .every4Weeks, .monthly, .monthlyFirst, .yearly]
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .every3Days:
            return calendar.date(byAdding: .day, value: 3, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .every2Weeks, .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .every3Weeks:
            return calendar.date(byAdding: .day, value: 21, to: date) ?? date
        case .every4Weeks:
            return calendar.date(byAdding: .day, value: 28, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .monthlyFirst:
            let comps = calendar.dateComponents([.year, .month], from: date)
            let thisFirst = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? date
            if calendar.startOfDay(for: date) < calendar.startOfDay(for: thisFirst) {
                return thisFirst
            }
            return calendar.date(byAdding: .month, value: 1, to: thisFirst) ?? date
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
    /// Account that receives recurring income (or pays recurring expenses).
    var accountID: UUID?

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
        lastGeneratedDate: Date? = nil,
        accountID: UUID? = nil
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
        self.accountID = accountID
    }

    enum CodingKeys: String, CodingKey {
        case id, title, amount, categoryID, category, type, frequency
        case startDate, nextDueDate, endDate, isActive, notes, lastGeneratedDate, accountID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Double.self, forKey: .amount)
        categoryID = try container.decode(String.self, forKey: .categoryID)
        category = try container.decodeIfPresent(Category.self, forKey: .category) ?? .others
        type = try container.decodeIfPresent(TransactionType.self, forKey: .type) ?? .expense
        frequency = try container.decodeIfPresent(RecurrenceFrequency.self, forKey: .frequency) ?? .monthly
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        nextDueDate = try container.decodeIfPresent(Date.self, forKey: .nextDueDate) ?? startDate
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        lastGeneratedDate = try container.decodeIfPresent(Date.self, forKey: .lastGeneratedDate)
        accountID = try container.decodeIfPresent(UUID.self, forKey: .accountID)
    }

    func makeExpense(on date: Date) -> Expense {
        Expense(
            title: title,
            price: amount,
            date: date,
            category: category,
            type: type,
            categoryID: categoryID,
            notes: notes.map { "Recurring · \($0)" } ?? "Recurring · \(frequency.displayName)",
            accountID: accountID
        )
    }
}
