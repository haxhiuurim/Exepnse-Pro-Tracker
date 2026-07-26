//
//  SpentTodayLiveActivityWidget.swift
//  iExpenseWidgetExtension
//

import ActivityKit
import WidgetKit
import SwiftUI

private enum LiveActivityColor {
    static let ink = Color(red: 0.090, green: 0.090, blue: 0.090)
    static let foam = Color(red: 0.969, green: 0.969, blue: 0.961)
    static let tide = Color(red: 0.008, green: 0.518, blue: 0.780)
    static let muted = Color(red: 0.451, green: 0.451, blue: 0.451)
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
                    Text("Inpenso · spent today")
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
