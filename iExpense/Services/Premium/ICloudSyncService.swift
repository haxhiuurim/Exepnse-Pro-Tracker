//
//  ICloudSyncService.swift
//  iExpense
//
//  Lightweight multi-device sync via iCloud KVS + mirrored App Group payloads.
//  Full CloudKit records can replace this later; this unlocks Pro sync today.
//

import Foundation
import WidgetKit

final class ICloudSyncService {
    static let shared = ICloudSyncService()

    private let store = NSUbiquitousKeyValueStore.default

    private enum Keys {
        static let expenses = "icloud.expenses"
        static let budgets = "icloud.budgets"
        static let categoryBudgets = "icloud.categoryBudgets"
        static let recurring = "icloud.recurring"
        static let lastPush = "icloud.lastPush"
    }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    func pushAll() {
        guard UserDefaults.standard.bool(forKey: "premiumiCloudSyncEnabled") else {
            return
        }

        if let expenses = try? JSONEncoder().encode(StorageService.loadExpenses()) {
            store.set(expenses, forKey: Keys.expenses)
        }
        if let budgets = try? JSONEncoder().encode(StorageService.loadBudgets()) {
            store.set(budgets, forKey: Keys.budgets)
        }
        if let categoryBudgets = try? JSONEncoder().encode(StorageService.loadCategoryBudgets()) {
            store.set(categoryBudgets, forKey: Keys.categoryBudgets)
        }
        if let recurring = try? JSONEncoder().encode(StorageService.loadRecurringTransactions()) {
            store.set(recurring, forKey: Keys.recurring)
        }
        store.set(Date().timeIntervalSince1970, forKey: Keys.lastPush)
        store.synchronize()
    }

    func pullIfAvailable() {
        store.synchronize()
        if let data = store.data(forKey: Keys.expenses),
           let expenses = try? JSONDecoder().decode([Expense].self, from: data) {
            StorageService.saveExpenses(expenses)
        }
        if let data = store.data(forKey: Keys.budgets),
           let budgets = try? JSONDecoder().decode([String: Double].self, from: data) {
            StorageService.saveBudgets(budgets)
        }
        if let data = store.data(forKey: Keys.categoryBudgets),
           let budgets = try? JSONDecoder().decode([String: Double].self, from: data) {
            StorageService.saveCategoryBudgets(budgets)
        }
        if let data = store.data(forKey: Keys.recurring),
           let items = try? JSONDecoder().decode([RecurringTransaction].self, from: data) {
            StorageService.saveRecurringTransactions(items)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    @objc private func storeDidChange(_ notification: Notification) {
        guard UserDefaults.standard.bool(forKey: "premiumiCloudSyncEnabled") else { return }
        pullIfAvailable()
        NotificationCenter.default.post(name: .inpensoICloudDidPull, object: nil)
    }
}

extension Notification.Name {
    static let inpensoICloudDidPull = Notification.Name("inpensoICloudDidPull")
}
