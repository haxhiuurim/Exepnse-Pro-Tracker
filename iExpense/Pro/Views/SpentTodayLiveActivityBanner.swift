//
//  SpentTodayLiveActivityViews.swift
//  iExpense
//
//  Note: Widget extension would normally host ActivityConfiguration.
//  Views here power in-app preview; extension configuration mirrors these.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct SpentTodayLiveActivityBanner: View {
    let amount: Double
    let currencyCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("LIVE · TODAY")
                    .font(InpensoTheme.label(10, weight: .bold))
                    .foregroundStyle(InpensoTheme.seafoam)
                Text(amount, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(22))
                    .foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: "wave.3.right")
                .foregroundStyle(InpensoTheme.seafoam)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(InpensoTheme.ink)
        )
    }
}
