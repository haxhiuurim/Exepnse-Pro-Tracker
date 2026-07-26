//
//  ExpenseViewModel.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftUI
import WidgetKit

@MainActor
class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var quickTemplates: [QuickSpendTemplate] = []

    init() {
        loadExpenses()
        quickTemplates = StorageService.loadQuickTemplates()
    }

    @discardableResult
    func addExpense(
        title: String,
        price: Double,
        date: Date,
        category: Category,
        type: TransactionType = .expense,
        categoryID: String? = nil,
        notes: String? = nil
    ) -> Expense {
        let newExpense = Expense(
            title: title,
            price: price,
            date: date,
            category: category,
            type: type,
            categoryID: categoryID,
            notes: notes
        )
        expenses.insert(newExpense, at: 0)
        saveExpenses()
        return newExpense
    }

    /// One-tap spend from a saved template.
    @discardableResult
    func addFromTemplate(_ template: QuickSpendTemplate) -> Expense {
        let expense = addExpense(
            title: template.title,
            price: template.amount,
            date: Date(),
            category: template.category,
            type: .expense,
            categoryID: template.categoryID
        )
        bumpTemplateUsage(template.id)
        return expense
    }

    func addExpenses(_ newExpenses: [Expense]) {
        expenses.insert(contentsOf: newExpenses, at: 0)
        saveExpenses()
    }

    func deleteExpense(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
        saveExpenses()
    }

    func saveExpenses() {
        StorageService.saveExpenses(expenses)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func loadExpenses() {
        expenses = StorageService.loadExpenses().sorted { $0.date > $1.date }
    }

    func deleteExpenses(_ expenses: [Expense]) {
        for expense in expenses {
            if let index = self.expenses.firstIndex(where: { $0.id == expense.id }) {
                self.expenses.remove(at: index)
            }
        }
        saveExpenses()
    }

    func updateExpense(_ expense: Expense) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[index] = expense
        saveExpenses()
    }

    // MARK: - Templates

    func saveTemplate(title: String, amount: Double, categoryID: String, category: Category) {
        let template = QuickSpendTemplate(
            title: title,
            amount: amount,
            categoryID: categoryID,
            category: category
        )
        quickTemplates.insert(template, at: 0)
        persistTemplates()
    }

    func removeTemplate(_ template: QuickSpendTemplate) {
        quickTemplates.removeAll { $0.id == template.id }
        persistTemplates()
    }

    func bumpTemplateUsage(_ id: UUID) {
        guard let index = quickTemplates.firstIndex(where: { $0.id == id }) else { return }
        quickTemplates[index].useCount += 1
        quickTemplates[index].lastUsed = Date()
        quickTemplates.sort {
            ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast)
        }
        persistTemplates()
    }

    private func persistTemplates() {
        StorageService.saveQuickTemplates(quickTemplates)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Period helpers

    func spent(for period: SpendingPeriod) -> Double {
        PeriodTotals.spent(from: expenses, period: period)
    }

    func income(for period: SpendingPeriod) -> Double {
        PeriodTotals.income(from: expenses, period: period)
    }

    func net(for period: SpendingPeriod) -> Double {
        PeriodTotals.net(from: expenses, period: period)
    }

    func recentExpenses(limit: Int = 5) -> [Expense] {
        Array(expenses.prefix(limit))
    }
}
