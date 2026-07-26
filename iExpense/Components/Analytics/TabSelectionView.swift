//
//  TabSelectionView.swift
//  iExpense
//

import SwiftUI

enum AnalyticsTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case trends = "Trends"
    case insights = "Insights"
    case budget = "Budget"

    var id: Self { self }
}

struct AnalyticsTabSelector: View {
    @Binding var selectedTab: AnalyticsTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                .fill(InpensoTheme.mist)
        )
    }

    private func tabButton(_ tab: AnalyticsTab) -> some View {
        let selected = selectedTab == tab
        return Button {
            HapticFeedback.selection()
            withAnimation(InpensoTheme.Motion.snappy) {
                selectedTab = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(selected ? InpensoTheme.ink : InpensoTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        .fill(selected ? InpensoTheme.panelFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: InpensoTheme.Space.md) {
        AnalyticsTabSelector(selectedTab: .constant(.overview))
    }
    .padding(InpensoTheme.Space.screen)
    .background(InpensoTheme.foam)
}
