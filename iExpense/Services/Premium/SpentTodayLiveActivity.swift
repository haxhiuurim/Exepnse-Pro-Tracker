//
//  SpentTodayLiveActivity.swift
//  iExpense
//

import Foundation
import ActivityKit

@MainActor
enum SpentTodayLiveActivity {
    static func startOrUpdate(amount: Double, currencyCode: String, isPro: Bool) {
        guard isPro else {
            endAll()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = SpentTodayAttributes.ContentState(
            amountSpent: amount,
            currencyCode: currencyCode,
            updatedAt: Date()
        )

        if let existing = Activity<SpentTodayAttributes>.activities.first {
            Task {
                await existing.update(ActivityContent(state: state, staleDate: nil))
            }
            return
        }

        let attributes = SpentTodayAttributes(title: "Spent today")
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state,
                    staleDate: Calendar.current.date(byAdding: .hour, value: 12, to: Date())
                ),
                pushType: nil
            )
        } catch {
            // Live Activities unavailable — ignore
        }
    }

    static func endAll() {
        for activity in Activity<SpentTodayAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
