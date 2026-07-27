//
//  SpentTodayLiveActivityWidget.swift
//  iExpenseWidgetExtension
//

import ActivityKit
import WidgetKit
import SwiftUI

private enum LiveActivityColor {
    static let ink = Color(red: 0.043, green: 0.106, blue: 0.200)
    static let foam = Color(red: 0.933, green: 0.945, blue: 0.965)
    static let tide = Color(red: 0.231, green: 0.431, blue: 0.961)
    static let muted = Color(red: 0.420, green: 0.478, blue: 0.565)
}

struct SpentTodayLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpentTodayAttributes.self) { context in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPENT TODAY")
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .foregroundStyle(LiveActivityColor.muted)
                    Text(context.state.amountSpent, format: .currency(code: context.state.currencyCode))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(LiveActivityColor.ink)
                }
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(LiveActivityColor.tide)
            }
            .padding()
            .activityBackgroundTint(LiveActivityColor.foam)
            .activitySystemActionForegroundColor(LiveActivityColor.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.amountSpent, format: .currency(code: context.state.currencyCode))
                        .font(.caption.weight(.bold))
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(AppBrand.name) · spent today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "dollarsign.circle.fill")
            } compactTrailing: {
                Text(context.state.amountSpent, format: .currency(code: context.state.currencyCode))
                    .font(.caption2.weight(.bold))
                    .minimumScaleFactor(0.5)
            } minimal: {
                Image(systemName: "dollarsign")
            }
        }
    }
}
