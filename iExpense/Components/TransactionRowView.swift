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

                Text(expense.date, format: .dateTime.month(.abbreviated).day())
                    .font(InpensoTheme.label(12))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: InpensoTheme.Space.xs)

            Text(amountText)
                .font(InpensoTheme.displayAmount(15))
                .foregroundStyle(expense.type == .income ? InpensoTheme.incomeTint : InpensoTheme.ink)
                .layoutPriority(1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var amountText: String {
        let formatted = expense.price.formatted(.currency(code: currencyCode))
        return expense.type == .income ? "+\(formatted)" : "−\(formatted)"
    }
}
