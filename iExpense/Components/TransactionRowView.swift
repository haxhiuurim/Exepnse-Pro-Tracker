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
        HStack(spacing: InpensoTheme.Space.sm + 2) {
            ZStack {
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm + 2, style: .continuous)
                    .fill(category.color.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: category.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(category.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)

                Text(expense.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(InpensoTheme.label(11, weight: .medium))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: InpensoTheme.Space.xs)

            Text(amountText)
                .font(InpensoTheme.displayAmount(15))
                .foregroundStyle(expense.type == .income ? InpensoTheme.positive : InpensoTheme.ink)
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
