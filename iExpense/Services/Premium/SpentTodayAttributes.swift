//
//  SpentTodayAttributes.swift
//  iExpense
//

import Foundation
import ActivityKit

struct SpentTodayAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var amountSpent: Double
        var currencyCode: String
        var updatedAt: Date
    }

    var title: String
}
