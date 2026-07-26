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
                Text("Spent today")
                    .font(InpensoTheme.label(11, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
                Text(amount, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(22))
                    .foregroundStyle(InpensoTheme.ink)
            }
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(InpensoTheme.tide)
        }
        .padding(InpensoTheme.Space.row)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .stroke(InpensoTheme.hairline, lineWidth: 1)
                )
        )
    }
}
