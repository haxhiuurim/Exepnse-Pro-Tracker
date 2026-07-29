//
//  BudgetAlertService.swift
//  iExpense
//
//  Local notifications when monthly / category budgets hit 80% and 100%.
//

import Foundation
import UserNotifications

@MainActor
enum BudgetAlertService {
    private static let prefix = "inpenso.budget.alert."

    static func evaluate(
        expenses: [Expense],
        monthlyBudget: Double,
        categoryBudgets: [String: Double],
        currencyCode: String
    ) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: Date()) else { return }

        let monthExpenses = expenses.filter { $0.type == .expense && month.contains($0.date) && !$0.isBalanceAdjustment }
        let totalSpent = monthExpenses.reduce(0.0) { $0 + $1.homeAmount }

        if monthlyBudget > 0 {
            await maybeNotify(
                id: "monthly",
                spent: totalSpent,
                limit: monthlyBudget,
                title80: "Budget almost used",
                body80: "You’ve used 80% of this month’s budget.",
                title100: "Budget reached",
                body100: "You’ve hit this month’s budget of \(format(monthlyBudget, currencyCode))."
            )
        }

        for (categoryID, limit) in categoryBudgets where limit > 0 {
            let spent = monthExpenses
                .filter { $0.categoryID == categoryID }
                .reduce(0.0) { $0 + $1.homeAmount }
            await maybeNotify(
                id: "cat.\(categoryID)",
                spent: spent,
                limit: limit,
                title80: "Category nearly full",
                body80: "A category budget is at 80%.",
                title100: "Category budget hit",
                body100: "A category reached its monthly limit of \(format(limit, currencyCode))."
            )
        }
    }

    private static func maybeNotify(
        id: String,
        spent: Double,
        limit: Double,
        title80: String,
        body80: String,
        title100: String,
        body100: String
    ) async {
        let ratio = spent / limit
        let monthKey = BudgetMonthKey.current()
        let defaults = UserDefaults.standard

        if ratio >= 1.0 {
            let key = "\(prefix)\(id).100.\(monthKey)"
            guard !defaults.bool(forKey: key) else { return }
            await schedule(identifier: key, title: title100, body: body100)
            defaults.set(true, forKey: key)
        } else if ratio >= 0.8 {
            let key = "\(prefix)\(id).80.\(monthKey)"
            guard !defaults.bool(forKey: key) else { return }
            await schedule(identifier: key, title: title80, body: body80)
            defaults.set(true, forKey: key)
        }
    }

    private static func schedule(identifier: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func format(_ value: Double, _ code: String) -> String {
        value.formatted(.currency(code: code))
    }
}
