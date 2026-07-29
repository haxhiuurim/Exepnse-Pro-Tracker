//
//  TransactionRowView.swift
//  iExpense
//

import SwiftUI

struct TransactionRowView: View {
    let expense: Expense
    let currencyCode: String
    let category: FinanceCategory

    var body: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            Image(systemName: category.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(category.color)
                .frame(width: 40, height: 40)
                .background(
                    category.color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(InpensoTheme.body(15, weight: .medium))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(expense.date, format: .dateTime.month(.abbreviated).day())
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                    if !expense.tags.isEmpty {
                        Text(expense.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                            .font(InpensoTheme.label(11, weight: .semibold))
                            .foregroundStyle(InpensoTheme.tide)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: InpensoTheme.Space.xs)

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(InpensoTheme.displayAmount(15))
                    .foregroundStyle(expense.type == .income ? InpensoTheme.incomeTint : InpensoTheme.ink)
                if expense.displayCurrencyCode.uppercased() != currencyCode.uppercased() {
                    Text(expense.homeAmount.formatted(.currency(code: currencyCode)))
                        .font(InpensoTheme.label(11))
                        .foregroundStyle(InpensoTheme.muted)
                }
            }
            .layoutPriority(1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var amountText: String {
        let code = expense.displayCurrencyCode
        let formatted = expense.price.formatted(.currency(code: code))
        return expense.type == .income ? "+\(formatted)" : "−\(formatted)"
    }
}
