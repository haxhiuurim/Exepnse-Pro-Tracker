//
//  ExchangeRateService.swift
//  iExpense
//
//  Offline-friendly FX for multi-currency logging. Rates are vs USD;
// conversion home←foreign uses cross rates.
//

import Foundation

enum ExchangeRateService {
    /// Approximate mid-market rates to 1 USD (enough for personal ledgers offline).
    private static let usdRates: [String: Double] = [
        "USD": 1,
        "EUR": 0.92,
        "GBP": 0.79,
        "CAD": 1.36,
        "AUD": 1.53,
        "JPY": 157,
        "CHF": 0.88,
        "CNY": 7.25,
        "INR": 83.5,
        "MXN": 17.1,
        "BRL": 5.1,
        "SEK": 10.5,
        "NOK": 10.7,
        "DKK": 6.9,
        "PLN": 3.95,
        "CZK": 23.2,
        "HUF": 360,
        "RON": 4.6,
        "TRY": 32.5,
        "ZAR": 18.5,
        "SGD": 1.35,
        "HKD": 7.82,
        "NZD": 1.66,
        "KRW": 1380,
        "THB": 36.5,
        "AED": 3.67,
        "SAR": 3.75,
        "ILS": 3.7,
        "PHP": 58,
        "IDR": 16200,
        "MYR": 4.7,
        "VND": 25400,
        "ALL": 92,
        "MDL": 17.5,
        "RSD": 108,
        "BAM": 1.8,
        "MKD": 56.5
    ]

    static func rate(from source: String, to target: String) -> Double {
        let from = source.uppercased()
        let to = target.uppercased()
        if from == to { return 1 }
        guard let fromUSD = usdRates[from], let toUSD = usdRates[to], fromUSD > 0 else {
            return 1
        }
        // 1 source = (1/fromUSD) USD; that many USD * toUSD = target
        return toUSD / fromUSD
    }

    static func convert(amount: Double, from: String, to: String, customRate: Double? = nil) -> Double {
        if let customRate, customRate > 0 {
            return amount * customRate
        }
        return amount * rate(from: from, to: to)
    }
}
