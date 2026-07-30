//
//  PremiumDataStore.swift
//  iExpense
//

import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class PremiumDataStore: ObservableObject {
    static let shared = PremiumDataStore()

    @Published var goals: [SavingsGoal] = []
    @Published var debts: [DebtLoan] = []
    @Published var merchantRules: [MerchantRule] = []
    @Published var accounts: [FinanceAccount] = []
    @Published var selectedThemeID: String = ThemePack.standard.id
    @Published var selectedIcon: AppIconOption = .classic
    @Published var iCloudSyncEnabled: Bool = false

    private enum Keys {
        static let goals = "premiumSavingsGoals"
        static let debts = "premiumDebtLoans"
        static let rules = "premiumMerchantRules"
        static let accounts = "premiumAccounts"
        static let theme = "premiumThemePackID"
        static let icon = "premiumAppIcon"
        static let iCloud = "premiumiCloudSyncEnabled"
    }

    init() {
        goals = load([SavingsGoal].self, key: Keys.goals) ?? []
        debts = load([DebtLoan].self, key: Keys.debts) ?? []
        merchantRules = load([MerchantRule].self, key: Keys.rules) ?? MerchantRule.starters
        accounts = load([FinanceAccount].self, key: Keys.accounts) ?? [
            FinanceAccount(name: "Wallet", kind: .cash, balance: 0),
            FinanceAccount(name: "Main checking", kind: .checking, balance: 0)
        ]
        selectedThemeID = ThemePack.standard.id
        UserDefaults.standard.set(ThemePack.standard.id, forKey: Keys.theme)
        selectedIcon = .classic
        iCloudSyncEnabled = UserDefaults.standard.bool(forKey: Keys.iCloud)
        UserDefaults.standard.removeObject(forKey: "premiumHousehold")
    }

    var netWorth: Double {
        accounts.filter(\.includeInNetWorth).reduce(0) { $0 + $1.signedBalance }
    }

    /// Cash available across liquid accounts (checking, savings, cash…).
    var availableCash: Double {
        accounts.filter { $0.includeInNetWorth && $0.isLiquid }.reduce(0) { $0 + $1.balance }
    }

    var primaryLiquidAccount: FinanceAccount? {
        accounts.first { $0.includeInNetWorth && $0.isLiquid }
            ?? accounts.first { $0.isLiquid }
    }

    var selectedTheme: ThemePack {
        ThemePack.standard
    }

    // MARK: - Goals

    func saveGoals() {
        persist(goals, key: Keys.goals)
        syncIfNeeded()
    }

    func upsertGoal(_ goal: SavingsGoal) {
        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[idx] = goal
        } else {
            goals.append(goal)
        }
        saveGoals()
    }

    func deleteGoal(_ goal: SavingsGoal) {
        goals.removeAll { $0.id == goal.id }
        saveGoals()
    }

    // MARK: - Debts / EMI

    func saveDebts() {
        persist(debts, key: Keys.debts)
        syncIfNeeded()
    }

    func upsertDebt(_ debt: DebtLoan) {
        if let idx = debts.firstIndex(where: { $0.id == debt.id }) {
            debts[idx] = debt
        } else {
            debts.append(debt)
        }
        saveDebts()
    }

    func deleteDebt(_ debt: DebtLoan) {
        debts.removeAll { $0.id == debt.id }
        saveDebts()
    }

    func recordDebtPayment(_ debt: DebtLoan, amount: Double) {
        guard let idx = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        debts[idx].recordPayment(amount)
        saveDebts()
    }

    // MARK: - Rules

    func saveRules() {
        persist(merchantRules, key: Keys.rules)
        syncIfNeeded()
    }

    func upsertRule(_ rule: MerchantRule) {
        if let idx = merchantRules.firstIndex(where: { $0.id == rule.id }) {
            merchantRules[idx] = rule
        } else {
            merchantRules.append(rule)
        }
        saveRules()
    }

    func deleteRule(_ rule: MerchantRule) {
        merchantRules.removeAll { $0.id == rule.id }
        saveRules()
    }

    func suggestedCategoryID(forTitle title: String) -> String? {
        merchantRules.first { $0.matches(title) }?.categoryID
    }

    // MARK: - Accounts

    func saveAccounts() {
        persist(accounts, key: Keys.accounts)
        syncIfNeeded()
    }

    func upsertAccount(_ account: FinanceAccount) {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
        saveAccounts()
    }

    /// Saves account and returns a ledger adjustment when the balance changed (for history / income).
    @discardableResult
    func upsertAccountRecordingChange(
        _ account: FinanceAccount,
        previous: FinanceAccount?
    ) -> Expense? {
        let oldBalance = previous?.balance ?? 0
        let newBalance = account.balance
        let delta = newBalance - oldBalance

        upsertAccount(account)

        guard abs(delta) > 0.000_1 else { return nil }

        let isIncome = delta > 0
        let amount = abs(delta)
        let title: String
        if previous == nil {
            title = isIncome ? "Opening balance · \(account.name)" : "Opening balance · \(account.name)"
        } else {
            title = isIncome ? "Balance increase · \(account.name)" : "Balance decrease · \(account.name)"
        }

        return Expense(
            title: title,
            price: amount,
            date: Date(),
            category: .others,
            type: isIncome ? .income : .expense,
            categoryID: Category.others.categoryID,
            notes: "Account adjustment",
            accountID: account.id,
            isBalanceAdjustment: true
        )
    }

    func adjustBalance(accountID: UUID?, by amount: Double) {
        guard abs(amount) > 0.000_1 else { return }
        let targetID = accountID ?? primaryLiquidAccount?.id
        guard let targetID,
              let idx = accounts.firstIndex(where: { $0.id == targetID }),
              accounts[idx].isLiquid
        else { return }

        accounts[idx].balance = max(0, accounts[idx].balance + amount)
        saveAccounts()
    }

    func applyTransactionToAccounts(_ expense: Expense, reversing: Bool = false) {
        guard !expense.isBalanceAdjustment else { return }
        let signed = expense.type == .income ? expense.homeAmount : -expense.homeAmount
        adjustBalance(accountID: expense.accountID, by: reversing ? -signed : signed)
    }

    func deleteAccount(_ account: FinanceAccount) {
        accounts.removeAll { $0.id == account.id }
        saveAccounts()
    }

    // MARK: - Theme / icon / iCloud

    func selectTheme(_ pack: ThemePack, isPro: Bool) -> Bool {
        if pack.requiresPro && !isPro { return false }
        selectedThemeID = pack.id
        UserDefaults.standard.set(pack.id, forKey: Keys.theme)
        syncIfNeeded()
        return true
    }

    func selectIcon(_ icon: AppIconOption, isPro: Bool) -> Bool {
        if icon.requiresPro && !isPro { return false }
        selectedIcon = icon
        UserDefaults.standard.set(icon.rawValue, forKey: Keys.icon)
        #if canImport(UIKit)
        if UIApplication.shared.supportsAlternateIcons {
            UIApplication.shared.setAlternateIconName(icon.alternateIconName) { _ in }
        }
        #endif
        return true
    }

    func setiCloudSync(_ enabled: Bool, isPro: Bool) -> Bool {
        // iCloud sync removed — cloud backup uses account login instead.
        iCloudSyncEnabled = false
        UserDefaults.standard.set(false, forKey: Keys.iCloud)
        return false
    }

    func replaceAccounts(_ value: [FinanceAccount]) {
        accounts = value
        persist(accounts, key: Keys.accounts)
    }

    func replaceGoals(_ value: [SavingsGoal]) {
        goals = value
        persist(goals, key: Keys.goals)
    }

    func replaceDebts(_ value: [DebtLoan]) {
        debts = value
        persist(debts, key: Keys.debts)
    }

    func replaceMerchantRules(_ value: [MerchantRule]) {
        merchantRules = value
        persist(merchantRules, key: Keys.rules)
    }

    private func syncIfNeeded() {
        CloudSyncService.shared.schedulePush()
    }

    // MARK: - Persistence helpers

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let defaults = UserDefaults(suiteName: StorageService.appGroupID) else { return }
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let defaults = UserDefaults(suiteName: StorageService.appGroupID) ?? .standard
        guard let data = defaults.data(forKey: key) ?? UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
