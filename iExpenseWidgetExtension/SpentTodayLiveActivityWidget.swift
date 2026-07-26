//
//  SpentTodayLiveActivityWidget.swift
//  iExpenseWidgetExtension
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SpentTodayLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpentTodayAttributes.self) { context in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPENT TODAY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(context.state.amountSpent, format: .currency(code: context.state.currencyCode))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
                Spacer()
                Image(systemName: "wave.3.right")
                    .foregroundStyle(Color(red: 0.48, green: 0.77, blue: 0.72))
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.05, green: 0.23, blue: 0.23).opacity(0.92))
            .activitySystemActionForegroundColor(.white)
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
