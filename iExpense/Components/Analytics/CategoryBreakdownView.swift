//
//  CategoryBreakdownView.swift
//  iExpense
//

import SwiftUI
import Charts

struct CategoryBreakdownView: View {
    @EnvironmentObject private var categoryStore: CategoryStore

    let spendingByCategory: [String: Double]
    let totalSpent: Double
    let currencyCode: String

    init(
        spendingByCategory: [String: Double],
        totalSpent: Double,
        currencyCode: String? = nil
    ) {
        self.spendingByCategory = spendingByCategory
        self.totalSpent = totalSpent
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }

    private var sortedCategories: [(key: String, value: Double)] {
        spendingByCategory.sorted { $0.value > $1.value }
    }

    var body: some View {
        SurfacePanel(padding: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                InpensoSectionHeader(title: "Spending by Category")

                if spendingByCategory.isEmpty {
                    Text("No category data for this period")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, InpensoTheme.Space.xl)
                } else {
                    Chart {
                        ForEach(sortedCategories, id: \.key) { categoryID, amount in
                            let category = categoryStore.category(for: categoryID)
                            SectorMark(
                                angle: .value("Amount", amount),
                                innerRadius: .ratio(0.62),
                                angularInset: 1
                            )
                            .foregroundStyle(category.color)
                            .cornerRadius(3)
                        }
                    }
                    .frame(height: 180)

                    VStack(spacing: 0) {
                        ForEach(Array(sortedCategories.enumerated()), id: \.element.key) { index, entry in
                            categoryRow(
                                category: categoryStore.category(for: entry.key),
                                amount: entry.value
                            )
                            if index < sortedCategories.count - 1 {
                                Divider().overlay(InpensoTheme.hairline)
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryRow(category: FinanceCategory, amount: Double) -> some View {
        let share = totalSpent > 0 ? amount / totalSpent : 0

        return HStack(spacing: InpensoTheme.Space.sm) {
            Circle()
                .fill(category.color)
                .frame(width: 8, height: 8)

            Text(category.displayName)
                .font(InpensoTheme.body(14))
                .foregroundStyle(InpensoTheme.ink)
                .lineLimit(1)

            Spacer(minLength: InpensoTheme.Space.sm)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(InpensoTheme.mist)
                    Capsule()
                        .fill(category.color.opacity(0.85))
                        .frame(width: geo.size.width * share)
                }
            }
            .frame(width: 72, height: 4)

            VStack(alignment: .trailing, spacing: 1) {
                Text(amount, format: .currency(code: currencyCode))
                    .font(InpensoTheme.label(13, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                if totalSpent > 0 {
                    Text("\(Int(share * 100))%")
                        .font(InpensoTheme.label(10))
                        .foregroundStyle(InpensoTheme.muted)
                }
            }
            .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.vertical, InpensoTheme.Space.sm)
    }
}

#Preview {
    let sampleData: [String: Double] = [
        Category.food.categoryID: 450.50,
        Category.transportation.categoryID: 220.75,
        Category.rent.categoryID: 1200.00,
        Category.entertainment.categoryID: 180.25,
        Category.utilities.categoryID: 310.80
    ]

    CategoryBreakdownView(
        spendingByCategory: sampleData,
        totalSpent: sampleData.values.reduce(0, +)
    )
    .environmentObject(CategoryStore())
    .padding(InpensoTheme.Space.screen)
    .background(InpensoTheme.foam)
}
