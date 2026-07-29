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
        static let accounts = "icloud.accounts"
        static let goals = "icloud.goals"
        static let debts = "icloud.debts"
        static let rules = "icloud.rules"
        static let customCategories = "icloud.customCategories"
        static let categoryCatalogState = "icloud.categoryCatalogState"
        static let quickTemplates = "icloud.quickTemplates"
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

    @MainActor
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

        let premium = PremiumDataStore.shared
        if let accountsData = try? JSONEncoder().encode(premium.accounts) {
            store.set(accountsData, forKey: Keys.accounts)
        }
        if let goalsData = try? JSONEncoder().encode(premium.goals) {
            store.set(goalsData, forKey: Keys.goals)
        }
        if let debtsData = try? JSONEncoder().encode(premium.debts) {
            store.set(debtsData, forKey: Keys.debts)
        }
        if let rulesData = try? JSONEncoder().encode(premium.merchantRules) {
            store.set(rulesData, forKey: Keys.rules)
        }

        if let customCategories = try? JSONEncoder().encode(StorageService.loadCustomCategories()) {
            store.set(customCategories, forKey: Keys.customCategories)
        }
        if let catalogState = StorageService.loadCategoryCatalogState(),
           let catalogData = try? JSONEncoder().encode(catalogState) {
            store.set(catalogData, forKey: Keys.categoryCatalogState)
        }
        if let templates = try? JSONEncoder().encode(StorageService.loadQuickTemplates()) {
            store.set(templates, forKey: Keys.quickTemplates)
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

        if let data = store.data(forKey: Keys.accounts),
           let accounts = try? JSONDecoder().decode([FinanceAccount].self, from: data) {
            Task { @MainActor in
                PremiumDataStore.shared.accounts = accounts
            }
        }

        if let data = store.data(forKey: Keys.goals),
           let goals = try? JSONDecoder().decode([SavingsGoal].self, from: data) {
            Task { @MainActor in
                PremiumDataStore.shared.goals = goals
            }
        }

        if let data = store.data(forKey: Keys.debts),
           let debts = try? JSONDecoder().decode([DebtLoan].self, from: data) {
            Task { @MainActor in
                PremiumDataStore.shared.debts = debts
            }
        }

        if let data = store.data(forKey: Keys.rules),
           let rules = try? JSONDecoder().decode([MerchantRule].self, from: data) {
            Task { @MainActor in
                PremiumDataStore.shared.merchantRules = rules
            }
        }

        if let data = store.data(forKey: Keys.customCategories),
           let cats = try? JSONDecoder().decode([FinanceCategory].self, from: data) {
            StorageService.saveCustomCategories(cats)
        }

        if let data = store.data(forKey: Keys.categoryCatalogState),
           let state = try? JSONDecoder().decode(CategoryCatalogState.self, from: data) {
            StorageService.saveCategoryCatalogState(state)
        }

        if let data = store.data(forKey: Keys.quickTemplates),
           let templates = try? JSONDecoder().decode([QuickSpendTemplate].self, from: data) {
            StorageService.saveQuickTemplates(templates)
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
