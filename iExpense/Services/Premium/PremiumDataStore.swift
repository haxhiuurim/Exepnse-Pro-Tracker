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
    @Published var merchantRules: [MerchantRule] = []
    @Published var accounts: [FinanceAccount] = []
    @Published var household: HouseholdLedger = .empty
    @Published var selectedThemeID: String = ThemePack.standard.id
    @Published var selectedIcon: AppIconOption = .classic
    @Published var iCloudSyncEnabled: Bool = false

    private enum Keys {
        static let goals = "premiumSavingsGoals"
        static let rules = "premiumMerchantRules"
        static let accounts = "premiumAccounts"
        static let household = "premiumHousehold"
        static let theme = "premiumThemePackID"
        static let icon = "premiumAppIcon"
        static let iCloud = "premiumiCloudSyncEnabled"
    }

    init() {
        goals = load([SavingsGoal].self, key: Keys.goals) ?? []
        merchantRules = load([MerchantRule].self, key: Keys.rules) ?? MerchantRule.starters
        accounts = load([FinanceAccount].self, key: Keys.accounts) ?? [
            FinanceAccount(name: "Wallet", kind: .cash, balance: 0),
            FinanceAccount(name: "Main checking", kind: .checking, balance: 0)
        ]
        household = load(HouseholdLedger.self, key: Keys.household) ?? .empty
        selectedThemeID = ThemePack.standard.id
        UserDefaults.standard.set(ThemePack.standard.id, forKey: Keys.theme)
        selectedIcon = .classic
        iCloudSyncEnabled = UserDefaults.standard.bool(forKey: Keys.iCloud)
    }

    var netWorth: Double {
        accounts.filter(\.includeInNetWorth).reduce(0) { $0 + $1.signedBalance }
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

    func deleteAccount(_ account: FinanceAccount) {
        accounts.removeAll { $0.id == account.id }
        saveAccounts()
    }

    // MARK: - Household

    func saveHousehold() {
        persist(household, key: Keys.household)
        syncIfNeeded()
    }

    func addHouseholdMember(name: String) {
        let colors = ["#059669", "#2563EB", "#D97706", "#16A34A", "#7C3AED"]
        let color = colors[household.members.count % colors.count]
        household.members.append(HouseholdMember(name: name, colorHex: color))
        saveHousehold()
    }

    func regenerateInviteCode() {
        household.inviteCode = String(UUID().uuidString.prefix(6)).uppercased()
        saveHousehold()
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
        guard isPro || !enabled else { return false }
        iCloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.iCloud)
        if enabled {
            ICloudSyncService.shared.pushAll()
        }
        return true
    }

    private func syncIfNeeded() {
        if iCloudSyncEnabled {
            ICloudSyncService.shared.pushAll()
        }
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
