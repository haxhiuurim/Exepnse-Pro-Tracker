//
//  NaturalLanguageExpenseParser.swift
//  iExpense
//
//  Parses phrases like "Coffee 4.50", "Lunch with team $65", "Uber 12.3".
//

import Foundation

struct ParsedExpenseDraft: Equatable {
    var title: String
    var amount: Double
    var suggestedCategoryID: String?
}

@MainActor
enum NaturalLanguageExpenseParser {
    static func parse(_ raw: String, categoryStore: CategoryStore? = nil) -> ParsedExpenseDraft? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let trailing = #"^(.*?)(?:\s+|\$|€|£)(\d+(?:[.,]\d{1,2})?)\s*$"#
        if let draft = match(trimmed, pattern: trailing) {
            return enrich(draft, categoryStore: categoryStore)
        }

        let leading = #"^(?:\$|€|£)?(\d+(?:[.,]\d{1,2})?)\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: leading),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           match.numberOfRanges >= 3,
           let amountRange = Range(match.range(at: 1), in: trimmed),
           let titleRange = Range(match.range(at: 2), in: trimmed) {
            let amountString = trimmed[amountRange].replacingOccurrences(of: ",", with: ".")
            guard let amount = Double(amountString), amount > 0 else { return nil }
            let title = String(trimmed[titleRange]).trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return nil }
            return enrich(ParsedExpenseDraft(title: title, amount: amount), categoryStore: categoryStore)
        }

        return nil
    }

    private static func match(_ text: String, pattern: String) -> ParsedExpenseDraft? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let titleRange = Range(match.range(at: 1), in: text),
              let amountRange = Range(match.range(at: 2), in: text) else { return nil }

        var title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "$-€£"))
        title = title.trimmingCharacters(in: .whitespaces)
        let amountString = text[amountRange].replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(amountString), amount > 0, !title.isEmpty else { return nil }
        return ParsedExpenseDraft(title: title, amount: amount)
    }

    private static func enrich(_ draft: ParsedExpenseDraft, categoryStore: CategoryStore?) -> ParsedExpenseDraft {
        var result = draft
        if let suggested = PremiumDataStore.shared.suggestedCategoryID(forTitle: draft.title) {
            result.suggestedCategoryID = suggested
        } else if let store = categoryStore {
            let lower = draft.title.lowercased()
            for category in store.visibleCategories {
                if lower.contains(category.displayName.lowercased()) {
                    result.suggestedCategoryID = category.id
                    break
                }
            }
        }
        return result
    }
}
