//
//  Expense.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation

struct Expense: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var price: Double
    var date: Date
    var category: Category
    var type: TransactionType
    var categoryID: String
    var notes: String?
    /// Linked account for cash tracking (optional for legacy rows).
    var accountID: UUID?
    /// When true, created from a manual balance edit — do not re-apply to account balance.
    var isBalanceAdjustment: Bool
    /// Free-form tags (normalized lowercase for matching).
    var tags: [String]
    /// Currency the user entered (`price` is in this currency). Nil = app home currency.
    var currencyCode: String?
    /// Optional explicit rate: 1 foreign unit → home currency. Nil uses offline table.
    var exchangeRateToHome: Double?

    init(
        id: UUID = UUID(),
        title: String,
        price: Double,
        date: Date,
        category: Category,
        type: TransactionType = .expense,
        categoryID: String? = nil,
        notes: String? = nil,
        accountID: UUID? = nil,
        isBalanceAdjustment: Bool = false,
        tags: [String] = [],
        currencyCode: String? = nil,
        exchangeRateToHome: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.date = date
        self.category = category
        self.type = type
        self.categoryID = categoryID ?? category.categoryID
        self.notes = notes
        self.accountID = accountID
        self.isBalanceAdjustment = isBalanceAdjustment
        self.tags = Self.normalizedTags(tags)
        self.currencyCode = currencyCode
        self.exchangeRateToHome = exchangeRateToHome
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case price
        case date
        case category
        case type
        case categoryID
        case notes
        case accountID
        case isBalanceAdjustment
        case tags
        case currencyCode
        case exchangeRateToHome
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        price = try container.decode(Double.self, forKey: .price)
        date = try container.decode(Date.self, forKey: .date)
        category = try container.decodeIfPresent(Category.self, forKey: .category) ?? .others
        type = try container.decodeIfPresent(TransactionType.self, forKey: .type) ?? .expense
        categoryID = try container.decodeIfPresent(String.self, forKey: .categoryID) ?? category.categoryID
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        accountID = try container.decodeIfPresent(UUID.self, forKey: .accountID)
        isBalanceAdjustment = try container.decodeIfPresent(Bool.self, forKey: .isBalanceAdjustment) ?? false
        tags = Self.normalizedTags(try container.decodeIfPresent([String].self, forKey: .tags) ?? [])
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
        exchangeRateToHome = try container.decodeIfPresent(Double.self, forKey: .exchangeRateToHome)
    }

    /// Amount converted into the app home currency for totals / budgets.
    var homeAmount: Double {
        let home = CurrencyCode.currentCurrencyCode()
        let source = (currencyCode?.isEmpty == false ? currencyCode! : home)
        if source.uppercased() == home.uppercased() { return price }
        return ExchangeRateService.convert(
            amount: price,
            from: source,
            to: home,
            customRate: exchangeRateToHome
        )
    }

    var displayCurrencyCode: String {
        if let currencyCode, !currencyCode.isEmpty { return currencyCode }
        return CurrencyCode.currentCurrencyCode()
    }

    static func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in tags {
            let cleaned = tag
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "#", with: "")
                .lowercased()
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }
            seen.insert(cleaned)
            result.append(cleaned)
        }
        return result
    }
}
