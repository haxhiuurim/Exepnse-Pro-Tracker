//
//  SummaryCardView.swift
//  iExpense
//

import SwiftUI

enum SummaryValueFormat {
    case currency
    case percent
    case days
    case count
    case noBudget
    case custom(formatter: (Double) -> String)
}

struct SummaryCard: View {
    let title: String
    let value: Double
    let valueFormat: SummaryValueFormat
    let icon: String
    var color: Color = InpensoTheme.tide
    var currencyCode: String

    init(
        title: String,
        value: Double,
        valueFormat: SummaryValueFormat,
        icon: String,
        color: Color = InpensoTheme.tide,
        currencyCode: String? = nil
    ) {
        self.title = title
        self.value = value
        self.valueFormat = valueFormat
        self.icon = icon
        self.color = color
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 28)
                .padding(.bottom, InpensoTheme.Space.sm)

            Text(title.uppercased())
                .font(InpensoTheme.label(11, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: InpensoTheme.Space.xs)

            formattedValue
                .font(InpensoTheme.displayAmount(20))
                .foregroundStyle(InpensoTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(InpensoTheme.Space.md)
        .frame(height: 104)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .stroke(InpensoTheme.hairline, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(accessibilityValueText)")
    }

    private var accessibilityValueText: String {
        switch valueFormat {
        case .currency:
            return value.formatted(.currency(code: currencyCode))
        case .percent:
            return "\(Int(value)) percent"
        case .days:
            return "\(Int(value)) days"
        case .count:
            return "\(Int(value))"
        case .noBudget:
            return "Not set"
        case .custom(let formatter):
            return formatter(value)
        }
    }

    @ViewBuilder
    private var formattedValue: some View {
        switch valueFormat {
        case .currency:
            Text(value, format: .currency(code: currencyCode))
        case .percent:
            Text("\(Int(value))%")
                .foregroundStyle(
                    value >= 90 ? InpensoTheme.danger :
                        (value >= 75 ? InpensoTheme.copperSoft : InpensoTheme.ink)
                )
        case .days:
            Text("\(Int(value)) days")
        case .count:
            Text("\(Int(value))")
        case .noBudget:
            Text("Not Set")
                .foregroundStyle(InpensoTheme.muted)
        case .custom(let formatter):
            Text(formatter(value))
        }
    }
}

struct SummaryCardGrid: View {
    var summaryCards: [SummaryCard]
    var columns: Int = 2

    var body: some View {
        let gridItems = Array(
            repeating: GridItem(.flexible(), spacing: InpensoTheme.Space.sm),
            count: columns
        )

        LazyVGrid(columns: gridItems, spacing: InpensoTheme.Space.sm) {
            ForEach(0..<summaryCards.count, id: \.self) { index in
                summaryCards[index]
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: InpensoTheme.Space.lg) {
        SummaryCardGrid(summaryCards: [
            SummaryCard(
                title: "Total Spent",
                value: 1234.56,
                valueFormat: .currency,
                icon: "dollarsign.circle.fill",
                color: InpensoTheme.tide
            ),
            SummaryCard(
                title: "Budget Used",
                value: 75,
                valueFormat: .percent,
                icon: "chart.pie.fill",
                color: InpensoTheme.copperSoft
            ),
            SummaryCard(
                title: "Days Left",
                value: 14,
                valueFormat: .days,
                icon: "calendar",
                color: InpensoTheme.slate
            ),
            SummaryCard(
                title: "Budget",
                value: 0,
                valueFormat: .noBudget,
                icon: "chart.pie.fill",
                color: InpensoTheme.muted
            )
        ])
    }
    .padding(InpensoTheme.Space.screen)
    .background(InpensoTheme.foam)
}
