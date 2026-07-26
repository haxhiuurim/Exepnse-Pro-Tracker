//
//  QuickSpendTemplate.swift
//  iExpense
//
//  Saved shortcuts for one-tap spending.
//

import Foundation

struct QuickSpendTemplate: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var amount: Double
    var categoryID: String
    var category: Category
    var useCount: Int
    var lastUsed: Date?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        categoryID: String,
        category: Category = .others,
        useCount: Int = 0,
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.categoryID = categoryID
        self.category = category
        self.useCount = useCount
        self.lastUsed = lastUsed
    }

    static let starterTemplates: [QuickSpendTemplate] = [
        QuickSpendTemplate(title: "Coffee", amount: 4.50, categoryID: Category.eatingOut.categoryID, category: .eatingOut),
        QuickSpendTemplate(title: "Lunch", amount: 12.00, categoryID: Category.eatingOut.categoryID, category: .eatingOut),
        QuickSpendTemplate(title: "Groceries", amount: 45.00, categoryID: Category.food.categoryID, category: .food),
        QuickSpendTemplate(title: "Transit", amount: 3.00, categoryID: Category.transportation.categoryID, category: .transportation)
    ]
}
