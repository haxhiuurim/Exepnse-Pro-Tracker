//
//  OnboardingStore.swift
//  iExpense
//
//  First-launch preferences that power Available Today + setup.
//

import Foundation
import Combine

@MainActor
final class OnboardingStore: ObservableObject {
    static let shared = OnboardingStore()

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.completed) }
    }

    /// Expected monthly take-home income used for Available Today.
    @Published var monthlyIncome: Double {
        didSet { defaults.set(monthlyIncome, forKey: Keys.monthlyIncome) }
    }

    /// Amount to set aside each month before discretionary spend.
    @Published var monthlySavingsTarget: Double {
        didSet { defaults.set(monthlySavingsTarget, forKey: Keys.savingsTarget) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let completed = "hasCompletedOnboarding"
        static let monthlyIncome = "onboardingMonthlyIncome"
        static let savingsTarget = "onboardingMonthlySavingsTarget"
        static let insightsPreviewStart = "insightsPreviewStartedAt"
    }

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: Keys.completed)
        monthlyIncome = defaults.object(forKey: Keys.monthlyIncome) as? Double ?? 0
        monthlySavingsTarget = defaults.object(forKey: Keys.savingsTarget) as? Double ?? 0

        // Existing installs already have a ledger — don't force first-launch onboarding.
        if !hasCompletedOnboarding, !StorageService.loadExpenses().isEmpty {
            hasCompletedOnboarding = true
            ensureInsightsPreviewStarted()
        }
    }

    func complete(
        currencyCode: String,
        monthlyIncome: Double,
        monthlySavingsTarget: Double,
        monthlyBudget: Double
    ) {
        self.monthlyIncome = max(0, monthlyIncome)
        self.monthlySavingsTarget = max(0, monthlySavingsTarget)
        defaults.set(currencyCode, forKey: "selectedCurrency")
        UserDefaults(suiteName: StorageService.appGroupID)?.set(currencyCode, forKey: "selectedCurrency")

        if monthlyBudget > 0 {
            var budgets = StorageService.loadBudgets()
            let key = BudgetMonthKey.current()
            budgets[key] = monthlyBudget
            StorageService.saveBudgets(budgets)
        }

        if defaults.object(forKey: Keys.insightsPreviewStart) == nil {
            defaults.set(Date(), forKey: Keys.insightsPreviewStart)
        }

        hasCompletedOnboarding = true
        HapticFeedback.success()
    }

    /// 14-day Insights preview from first onboarding completion.
    var insightsPreviewActive: Bool {
        guard let start = defaults.object(forKey: Keys.insightsPreviewStart) as? Date else { return false }
        return Date().timeIntervalSince(start) < 14 * 24 * 60 * 60
    }

    var insightsPreviewDaysRemaining: Int {
        guard let start = defaults.object(forKey: Keys.insightsPreviewStart) as? Date else { return 0 }
        let remaining = 14 - Int(Date().timeIntervalSince(start) / 86_400)
        return max(0, remaining)
    }

    func ensureInsightsPreviewStarted() {
        if defaults.object(forKey: Keys.insightsPreviewStart) == nil {
            defaults.set(Date(), forKey: Keys.insightsPreviewStart)
        }
    }
}

enum BudgetMonthKey {
    static func current(date: Date = Date(), calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }
}
