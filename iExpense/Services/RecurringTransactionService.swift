//
//  RecurringTransactionService.swift
//  iExpense
//
//  Generates due recurring expenses/income on launch and foreground.
//

import Foundation
import WidgetKit

@MainActor
final class RecurringTransactionService: ObservableObject {
    static let shared = RecurringTransactionService()

    @Published var items: [RecurringTransaction] = []

    init() {
        items = StorageService.loadRecurringTransactions()
    }

    func reload() {
        items = StorageService.loadRecurringTransactions()
    }

    func save(_ items: [RecurringTransaction]) {
        self.items = items.sorted { $0.nextDueDate < $1.nextDueDate }
        StorageService.saveRecurringTransactions(self.items)
    }

    func upsert(_ item: RecurringTransaction) {
        var copy = items
        if let index = copy.firstIndex(where: { $0.id == item.id }) {
            copy[index] = item
        } else {
            copy.append(item)
        }
        save(copy)
    }

    func delete(_ item: RecurringTransaction) {
        save(items.filter { $0.id != item.id })
    }

    func toggleActive(_ item: RecurringTransaction) {
        var updated = item
        updated.isActive.toggle()
        upsert(updated)
    }

    /// Creates any due expenses and advances nextDueDate. Returns new expenses.
    @discardableResult
    func processDueTransactions(into expenseStore: ExpenseViewModel, now: Date = Date()) -> [Expense] {
        var created: [Expense] = []
        var updatedItems = items
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)

        for index in updatedItems.indices {
            guard updatedItems[index].isActive else { continue }

            // Cap catch-up so a long offline stretch doesn't flood the ledger
            var safety = 0
            while updatedItems[index].isActive,
                  calendar.startOfDay(for: updatedItems[index].nextDueDate) <= todayStart,
                  safety < 36 {
                if let end = updatedItems[index].endDate,
                   calendar.startOfDay(for: updatedItems[index].nextDueDate) > calendar.startOfDay(for: end) {
                    updatedItems[index].isActive = false
                    break
                }

                let due = updatedItems[index].nextDueDate
                let expense = updatedItems[index].makeExpense(on: due)
                created.append(expense)
                updatedItems[index].lastGeneratedDate = due
                updatedItems[index].nextDueDate = updatedItems[index].frequency.nextDate(after: due)

                if let end = updatedItems[index].endDate,
                   calendar.startOfDay(for: updatedItems[index].nextDueDate) > calendar.startOfDay(for: end) {
                    updatedItems[index].isActive = false
                }
                safety += 1
            }
        }

        if !created.isEmpty {
            expenseStore.addExpenses(created)
            save(updatedItems)
            WidgetCenter.shared.reloadAllTimelines()
        } else if updatedItems != items {
            save(updatedItems)
        }

        return created
    }
}
