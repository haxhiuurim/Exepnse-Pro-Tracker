//
//  CloudSyncService.swift
//  iExpense
//
//  Persists the personal ledger to the Expense backend when logged in.
//  Replaces iCloud KVS sync.
//

import Foundation
import WidgetKit

extension Notification.Name {
    static let expenseCloudDidPull = Notification.Name("expenseCloudDidPull")
}

@MainActor
final class CloudSyncService {
    static let shared = CloudSyncService()

    private var pushTask: Task<Void, Never>?
    private(set) var lastSyncedAt: Date?

    private init() {}

    func schedulePush() {
        guard AuthSession.shared.isLoggedIn else { return }
        pushTask?.cancel()
        pushTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await pushAll()
        }
    }

    func pushAll() async {
        guard AuthSession.shared.isLoggedIn else { return }

        let premium = PremiumDataStore.shared
        var documents: [String: Any] = [:]

        if let data = try? JSONEncoder().encode(StorageService.loadExpenses()),
           let json = try? JSONSerialization.jsonObject(with: data) {
            documents["expenses"] = json
        }
        if let data = try? JSONEncoder().encode(StorageService.loadBudgets()),
           let json = try? JSONSerialization.jsonObject(with: data) {
            documents["budgets"] = json
        }
        if let data = try? JSONEncoder().encode(StorageService.loadCategoryBudgets()),
           let json = try? JSONSerialization.jsonObject(with: data) {
            documents["category_budgets"] = json
        }
        if let data = try? JSONEncoder().encode(StorageService.loadRecurringTransactions()),
           let json = try? JSONSerialization.jsonObject(with: data) {
            documents["recurring"] = json
        }
        if let data = try? JSONEncoder().encode(premium.accounts),
           let json = try? JSONSerialization.jsonObject(with: data) {
            documents["accounts"] = json
        }
        if let data = try? JSONEncoder().encode(premium.goals),
           let json = try? JSONSerialization.jsonObject(with: data) {
            documents["goals"] = json
        }
        if let data = try? JSONEncoder().encode(premium.debts),
           let json = try? JSONSerialization.jsonObject(with: data) {
            documents["debts"] = json
        }
        if let data = try? JSONEncoder().encode(premium.merchantRules),
           let json = try? JSONSerialization.jsonObject(with: data) {
            documents["merchant_rules"] = json
        }

        var catalog: [String: Any] = [:]
        if let custom = try? JSONEncoder().encode(StorageService.loadCustomCategories()),
           let json = try? JSONSerialization.jsonObject(with: custom) {
            catalog["custom_categories"] = json
        }
        if let state = StorageService.loadCategoryCatalogState(),
           let data = try? JSONEncoder().encode(state),
           let json = try? JSONSerialization.jsonObject(with: data) {
            catalog["catalog_state"] = json
        }
        if let templates = try? JSONEncoder().encode(StorageService.loadQuickTemplates()),
           let json = try? JSONSerialization.jsonObject(with: templates) {
            catalog["quick_templates"] = json
        }
        documents["category_catalog"] = catalog

        documents["settings"] = [
            "currency": UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD",
            "monthly_income": OnboardingStore.shared.monthlyIncome,
            "monthly_savings_target": OnboardingStore.shared.monthlySavingsTarget
        ]

        documents["trip_shortcuts"] = TripShortcutsStore.shared.encodedPayload()

        do {
            _ = try await SharedTripAPI.shared.pushSync(documents: documents)
            lastSyncedAt = Date()
        } catch {
            // Soft-fail; next schedule retries.
        }
    }

    func pullIfAvailable() async {
        guard AuthSession.shared.isLoggedIn else { return }
        do {
            let docs = try await SharedTripAPI.shared.pullSync()
            apply(documents: docs)
            lastSyncedAt = Date()
            NotificationCenter.default.post(name: .expenseCloudDidPull, object: nil)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Soft-fail.
        }
    }

    private func apply(documents: [String: Any]) {
        if let raw = documents["expenses"],
           let data = try? JSONSerialization.data(withJSONObject: raw),
           let expenses = try? JSONDecoder().decode([Expense].self, from: data) {
            StorageService.saveExpenses(expenses)
        }
        if let raw = documents["budgets"],
           let data = try? JSONSerialization.data(withJSONObject: raw),
           let budgets = try? JSONDecoder().decode([String: Double].self, from: data) {
            StorageService.saveBudgets(budgets)
        }
        if let raw = documents["category_budgets"],
           let data = try? JSONSerialization.data(withJSONObject: raw),
           let budgets = try? JSONDecoder().decode([String: Double].self, from: data) {
            StorageService.saveCategoryBudgets(budgets)
        }
        if let raw = documents["recurring"],
           let data = try? JSONSerialization.data(withJSONObject: raw),
           let items = try? JSONDecoder().decode([RecurringTransaction].self, from: data) {
            StorageService.saveRecurringTransactions(items)
        }

        let premium = PremiumDataStore.shared
        if let raw = documents["accounts"],
           let data = try? JSONSerialization.data(withJSONObject: raw),
           let accounts = try? JSONDecoder().decode([FinanceAccount].self, from: data) {
            premium.replaceAccounts(accounts)
        }
        if let raw = documents["goals"],
           let data = try? JSONSerialization.data(withJSONObject: raw),
           let goals = try? JSONDecoder().decode([SavingsGoal].self, from: data) {
            premium.replaceGoals(goals)
        }
        if let raw = documents["debts"],
           let data = try? JSONSerialization.data(withJSONObject: raw),
           let debts = try? JSONDecoder().decode([DebtLoan].self, from: data) {
            premium.replaceDebts(debts)
        }
        if let raw = documents["merchant_rules"],
           let data = try? JSONSerialization.data(withJSONObject: raw),
           let rules = try? JSONDecoder().decode([MerchantRule].self, from: data) {
            premium.replaceMerchantRules(rules)
        }

        if let catalog = documents["category_catalog"] as? [String: Any] {
            if let raw = catalog["custom_categories"],
               let data = try? JSONSerialization.data(withJSONObject: raw),
               let cats = try? JSONDecoder().decode([FinanceCategory].self, from: data) {
                StorageService.saveCustomCategories(cats)
            }
            if let raw = catalog["catalog_state"],
               let data = try? JSONSerialization.data(withJSONObject: raw),
               let state = try? JSONDecoder().decode(CategoryCatalogState.self, from: data) {
                StorageService.saveCategoryCatalogState(state)
            }
            if let raw = catalog["quick_templates"],
               let data = try? JSONSerialization.data(withJSONObject: raw),
               let templates = try? JSONDecoder().decode([QuickSpendTemplate].self, from: data) {
                StorageService.saveQuickTemplates(templates)
            }
        }

        if let settings = documents["settings"] as? [String: Any] {
            if let currency = settings["currency"] as? String, !currency.isEmpty {
                UserDefaults.standard.set(currency, forKey: "selectedCurrency")
                UserDefaults(suiteName: StorageService.appGroupID)?.set(currency, forKey: "selectedCurrency")
            }
            if let income = settings["monthly_income"] as? Double {
                OnboardingStore.shared.monthlyIncome = income
            }
            if let savings = settings["monthly_savings_target"] as? Double {
                OnboardingStore.shared.monthlySavingsTarget = savings
            }
        }

        if let shortcuts = documents["trip_shortcuts"] {
            TripShortcutsStore.shared.applyServerPayload(shortcuts)
        }
    }
}
