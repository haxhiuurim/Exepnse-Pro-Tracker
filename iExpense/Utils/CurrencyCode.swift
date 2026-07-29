//
//  CurrencyCode.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation

enum CurrencyCode {
    static func currentCurrencyCode() -> String {
        if let stored = UserDefaults.standard.string(forKey: "selectedCurrency"), !stored.isEmpty {
            return stored
        }
        if let shared = UserDefaults(suiteName: StorageService.appGroupID)?
            .string(forKey: "selectedCurrency"), !shared.isEmpty {
            return shared
        }
        return Locale.current.currency?.identifier ?? "USD"
    }
}

/// Legacy free function kept for call sites / widgets.
func currentCurrencyCode() -> String {
    CurrencyCode.currentCurrencyCode()
}
