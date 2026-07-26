//
//  CategoryBudget.swift
//  iExpense
//
//  Per-category monthly spending limits.
//

import Foundation

struct CategoryBudget: Identifiable, Codable, Equatable, Hashable {
    var id: String { categoryID }
    var categoryID: String
    var monthlyLimit: Double

    init(categoryID: String, monthlyLimit: Double) {
        self.categoryID = categoryID
        self.monthlyLimit = monthlyLimit
    }
}

enum CategoryBudgetStore {
    /// categoryID → monthly limit
    static func load() -> [String: Double] {
        StorageService.loadCategoryBudgets()
    }

    static func save(_ budgets: [String: Double]) {
        StorageService.saveCategoryBudgets(budgets)
    }

    static func limit(for categoryID: String, in budgets: [String: Double]) -> Double {
        budgets[categoryID] ?? 0
    }

    static func progress(spent: Double, limit: Double) -> Double {
        guard limit > 0 else { return 0 }
        return min(1.0, spent / limit)
    }
}
