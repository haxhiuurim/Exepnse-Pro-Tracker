//
//  PremiumModels.swift
//  iExpense
//

import Foundation
import SwiftUI

// MARK: - Savings goals & envelopes

struct SavingsGoal: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var accentHex: String
    var iconName: String
    var deadline: Date?
    var isEnvelope: Bool

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        accentHex: String = "#2A8F87",
        iconName: String = "target",
        deadline: Date? = nil,
        isEnvelope: Bool = false
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.accentHex = accentHex
        self.iconName = iconName
        self.deadline = deadline
        self.isEnvelope = isEnvelope
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, currentAmount / targetAmount)
    }

    var accent: Color { Color(hex: accentHex) ?? InpensoTheme.tide }
}

// MARK: - Debt / EMI (local payoff plans)

struct DebtLoan: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var principal: Double
    /// Remaining balance to pay off.
    var remaining: Double
    /// Fixed installment amount (EMI).
    var emiAmount: Double
    var annualInterestPercent: Double
    var nextDueDate: Date
    var notes: String?
    var accentHex: String

    init(
        id: UUID = UUID(),
        name: String,
        principal: Double,
        remaining: Double? = nil,
        emiAmount: Double,
        annualInterestPercent: Double = 0,
        nextDueDate: Date = Date(),
        notes: String? = nil,
        accentHex: String = "#C45C26"
    ) {
        self.id = id
        self.name = name
        self.principal = principal
        self.remaining = remaining ?? principal
        self.emiAmount = emiAmount
        self.annualInterestPercent = annualInterestPercent
        self.nextDueDate = nextDueDate
        self.notes = notes
        self.accentHex = accentHex
    }

    var progress: Double {
        guard principal > 0 else { return 0 }
        return min(1, max(0, (principal - remaining) / principal))
    }

    var monthsRemainingEstimate: Int {
        guard emiAmount > 0, remaining > 0 else { return 0 }
        return Int(ceil(remaining / emiAmount))
    }

    var accent: Color { Color(hex: accentHex) ?? InpensoTheme.expenseTint }

    mutating func recordPayment(_ amount: Double, calendar: Calendar = .current) {
        let paid = min(remaining, max(0, amount))
        remaining = max(0, remaining - paid)
        if let next = calendar.date(byAdding: .month, value: 1, to: nextDueDate) {
            nextDueDate = next
        }
    }
}

// MARK: - Merchant rules

struct MerchantRule: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var matchText: String
    var categoryID: String
    var isEnabled: Bool

    init(id: UUID = UUID(), matchText: String, categoryID: String, isEnabled: Bool = true) {
        self.id = id
        self.matchText = matchText
        self.categoryID = categoryID
        self.isEnabled = isEnabled
    }

    static let starters: [MerchantRule] = [
        MerchantRule(matchText: "Uber", categoryID: Category.transportation.categoryID),
        MerchantRule(matchText: "Lyft", categoryID: Category.transportation.categoryID),
        MerchantRule(matchText: "Starbucks", categoryID: Category.eatingOut.categoryID),
        MerchantRule(matchText: "Netflix", categoryID: Category.subscriptions.categoryID),
        MerchantRule(matchText: "Spotify", categoryID: Category.subscriptions.categoryID),
        MerchantRule(matchText: "Amazon", categoryID: Category.shopping.categoryID),
        MerchantRule(matchText: "Whole Foods", categoryID: Category.food.categoryID)
    ]

    func matches(_ title: String) -> Bool {
        guard isEnabled else { return false }
        return title.localizedCaseInsensitiveContains(matchText)
    }
}

// MARK: - Accounts / net worth

enum AccountKind: String, CaseIterable, Identifiable, Codable {
    case cash, checking, savings, creditCard, investment, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .checking: return "Checking"
        case .savings: return "Savings"
        case .creditCard: return "Credit card"
        case .investment: return "Investment"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .cash: return "banknote"
        case .checking: return "building.columns"
        case .savings: return "leaf.fill"
        case .creditCard: return "creditcard"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .other: return "tray.full"
        }
    }

    /// Credit cards subtract from net worth.
    var countsAsLiability: Bool { self == .creditCard }
}

struct FinanceAccount: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var kind: AccountKind
    var balance: Double
    var includeInNetWorth: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: AccountKind,
        balance: Double,
        includeInNetWorth: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.balance = balance
        self.includeInNetWorth = includeInNetWorth
    }

    var signedBalance: Double {
        kind.countsAsLiability ? -abs(balance) : balance
    }

    /// Liquid money available to spend (excludes credit cards).
    var isLiquid: Bool { !kind.countsAsLiability }
}

// MARK: - Single app theme (no pack picker)

struct ThemePack: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let ink: Color
    let accent: Color
    let mist: Color
    let requiresPro: Bool

    /// Only one visual theme ships with the app.
    static let standard = ThemePack(
        id: "north",
        name: "North",
        tagline: "Navy canvas, cobalt accent",
        ink: Color(inpensoHex: "#0B1B33"),
        accent: Color(inpensoHex: "#3B6EF5"),
        mist: Color(inpensoHex: "#E4EAF3"),
        requiresPro: false
    )

    static let all: [ThemePack] = [standard]
}

enum AppIconOption: String, CaseIterable, Identifiable {
    case classic

    var id: String { rawValue }
    var displayName: String { "Classic" }
    var requiresPro: Bool { false }
    var alternateIconName: String? { nil }
}
