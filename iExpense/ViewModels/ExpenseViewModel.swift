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

    private var accountsStore: PremiumDataStore { .shared }

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
        notes: String? = nil,
        accountID: UUID? = nil,
        isBalanceAdjustment: Bool = false,
        applyToAccount: Bool = true,
        tags: [String] = [],
        currencyCode: String? = nil,
        exchangeRateToHome: Double? = nil
    ) -> Expense {
        let linkedAccount = accountID ?? (isBalanceAdjustment ? nil : accountsStore.primaryLiquidAccount?.id)
        let newExpense = Expense(
            title: title,
            price: price,
            date: date,
            category: category,
            type: type,
            categoryID: categoryID,
            notes: notes,
            accountID: linkedAccount ?? accountID,
            isBalanceAdjustment: isBalanceAdjustment,
            tags: tags,
            currencyCode: currencyCode,
            exchangeRateToHome: exchangeRateToHome
        )
        expenses.insert(newExpense, at: 0)
        if applyToAccount {
            accountsStore.applyTransactionToAccounts(newExpense)
        }
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
        for expense in newExpenses {
            var linked = expense
            if linked.accountID == nil, !linked.isBalanceAdjustment {
                linked.accountID = accountsStore.primaryLiquidAccount?.id
            }
            expenses.insert(linked, at: 0)
            accountsStore.applyTransactionToAccounts(linked)
        }
        saveExpenses()
    }

    /// Persist a manual account balance change as income/expense history.
    @discardableResult
    func recordAccountBalanceChange(account: FinanceAccount, previous: FinanceAccount?) -> Expense? {
        guard let adjustment = accountsStore.upsertAccountRecordingChange(account, previous: previous) else {
            return nil
        }
        expenses.insert(adjustment, at: 0)
        saveExpenses()
        return adjustment
    }

    func deleteExpense(at offsets: IndexSet) {
        for index in offsets {
            accountsStore.applyTransactionToAccounts(expenses[index], reversing: true)
        }
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
                accountsStore.applyTransactionToAccounts(self.expenses[index], reversing: true)
                self.expenses.remove(at: index)
            }
        }
        saveExpenses()
    }

    func updateExpense(_ expense: Expense) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        let previous = expenses[index]
        accountsStore.applyTransactionToAccounts(previous, reversing: true)
        var updated = expense
        if updated.accountID == nil, !updated.isBalanceAdjustment {
            updated.accountID = previous.accountID ?? accountsStore.primaryLiquidAccount?.id
        }
        expenses[index] = updated
        accountsStore.applyTransactionToAccounts(updated)
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

    func transactions(forAccountID id: UUID) -> [Expense] {
        expenses.filter { $0.accountID == id }
    }

    var allUniqueTags: Set<String> {
        Set(expenses.flatMap(\.tags))
    }
}
