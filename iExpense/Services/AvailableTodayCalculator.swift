//
//  AvailableTodayCalculator.swift
//  iExpense
//
//  PocketGuard / BentoMoney-style “what can I safely spend today?”
//

import Foundation

struct AvailableTodayResult: Equatable {
    /// Safe daily spend remaining for today (capped by liquid cash when provided).
    var amount: Double
    /// Pace-based daily amount before cash cap.
    var paceAmount: Double
    /// Full month discretionary pool after bills & savings.
    var monthPool: Double
    /// Already spent this calendar month (expenses only).
    var spentThisMonth: Double
    /// Monthly bill estimate from active recurring expenses.
    var monthlyBills: Double
    var monthlyIncome: Double
    var monthlySavingsTarget: Double
    var daysRemainingInMonth: Int
    /// Liquid cash used as a hard ceiling (nil = no cap).
    var liquidCash: Double?

    var isConfigured: Bool {
        monthlyIncome > 0.01 || monthlyBills > 0.01 || (liquidCash ?? 0) > 0.01
    }
}

enum AvailableTodayCalculator {
    static func compute(
        expenses: [Expense],
        recurring: [RecurringTransaction],
        monthlyIncomeOverride: Double,
        monthlySavingsTarget: Double,
        liquidCash: Double? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AvailableTodayResult {
        let monthInterval = calendar.dateInterval(of: .month, for: now)
            ?? DateInterval(start: now, end: now)

        let spentThisMonth = expenses
            .filter { $0.type == .expense && monthInterval.contains($0.date) && !$0.isBalanceAdjustment }
            .reduce(0.0) { $0 + $1.homeAmount }

        let loggedIncome = expenses
            .filter { $0.type == .income && monthInterval.contains($0.date) && !$0.isBalanceAdjustment }
            .reduce(0.0) { $0 + $1.homeAmount }

        let monthlyBills = recurring
            .filter { $0.isActive && $0.type == .expense }
            .reduce(0.0) { $0 + monthlyEquivalent(amount: $1.amount, frequency: $1.frequency) }

        let recurringIncome = recurring
            .filter { $0.isActive && $0.type == .income }
            .reduce(0.0) { $0 + monthlyEquivalent(amount: $1.amount, frequency: $1.frequency) }

        let monthlyIncome = max(monthlyIncomeOverride, loggedIncome, recurringIncome)
        let pool = monthlyIncome - monthlyBills - max(0, monthlySavingsTarget)
        let remainingPool = pool - spentThisMonth

        let day = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let daysRemaining = max(1, daysInMonth - day + 1)

        let paceAmount = remainingPool / Double(daysRemaining)
        // Never suggest spending more than cash on hand.
        let capped: Double
        if let liquidCash {
            capped = min(paceAmount, max(0, liquidCash))
        } else {
            capped = paceAmount
        }

        return AvailableTodayResult(
            amount: capped,
            paceAmount: paceAmount,
            monthPool: pool,
            spentThisMonth: spentThisMonth,
            monthlyBills: monthlyBills,
            monthlyIncome: monthlyIncome,
            monthlySavingsTarget: monthlySavingsTarget,
            daysRemainingInMonth: daysRemaining,
            liquidCash: liquidCash
        )
    }

    static func monthlyEquivalent(amount: Double, frequency: RecurrenceFrequency) -> Double {
        switch frequency {
        case .daily:
            return amount * 30
        case .every3Days:
            return amount * 10
        case .weekly:
            return amount * 52 / 12
        case .every2Weeks, .biweekly:
            return amount * 26 / 12
        case .every3Weeks:
            return amount * (52 / 3) / 12
        case .every4Weeks:
            return amount
        case .monthly, .monthlyFirst:
            return amount
        case .yearly:
            return amount / 12
        }
    }
}
