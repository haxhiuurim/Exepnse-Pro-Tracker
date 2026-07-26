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
}

// MARK: - Household

struct HouseholdMember: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var isOwner: Bool

    init(id: UUID = UUID(), name: String, colorHex: String = "#2A8F87", isOwner: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isOwner = isOwner
    }
}

struct HouseholdLedger: Codable, Equatable {
    var name: String
    var inviteCode: String
    var members: [HouseholdMember]
    var sharedCategoryIDs: [String]

    static var empty: HouseholdLedger {
        HouseholdLedger(
            name: "Household",
            inviteCode: String(UUID().uuidString.prefix(6)).uppercased(),
            members: [HouseholdMember(name: "You", isOwner: true)],
            sharedCategoryIDs: []
        )
    }
}

// MARK: - Theme packs

struct ThemePack: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let ink: Color
    let accent: Color
    let mist: Color
    let requiresPro: Bool

    static let all: [ThemePack] = [
        ThemePack(
            id: "tide",
            name: "Field Notes",
            tagline: "Charcoal ink on paper white",
            ink: Color(inpensoHex: "#171717"),
            accent: Color(inpensoHex: "#171717"),
            mist: Color(inpensoHex: "#F0F0EE"),
            requiresPro: false
        ),
        ThemePack(
            id: "midnight",
            name: "Harbor Blue",
            tagline: "Navy & trust blue",
            ink: Color(inpensoHex: "#0B1F33"),
            accent: Color(inpensoHex: "#2563EB"),
            mist: Color(inpensoHex: "#E8EEF5"),
            requiresPro: true
        ),
        ThemePack(
            id: "ember",
            name: "Ember Desk",
            tagline: "Warm charcoal & amber",
            ink: Color(inpensoHex: "#1C1917"),
            accent: Color(inpensoHex: "#D97706"),
            mist: Color(inpensoHex: "#F5F0EB"),
            requiresPro: true
        ),
        ThemePack(
            id: "forest",
            name: "Pine Ledger",
            tagline: "Deep green focus",
            ink: Color(inpensoHex: "#14532D"),
            accent: Color(inpensoHex: "#16A34A"),
            mist: Color(inpensoHex: "#EAF5EE"),
            requiresPro: true
        )
    ]
}

enum AppIconOption: String, CaseIterable, Identifiable {
    case classic, tide, copper, ink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .tide: return "Tide"
        case .copper: return "Copper"
        case .ink: return "Ink"
        }
    }

    var requiresPro: Bool { self != .classic }

    /// Alternate icon name in asset catalog (nil = primary).
    var alternateIconName: String? {
        switch self {
        case .classic: return nil
        case .tide: return "AppIconTide"
        case .copper: return "AppIconCopper"
        case .ink: return "AppIconInk"
        }
    }
}
