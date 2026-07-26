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
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(category.color.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: category.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(category.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)

                Text(expense.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(InpensoTheme.label(12, weight: .medium))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: 8)

            Text(amountText)
                .font(InpensoTheme.displayAmount(16))
                .foregroundStyle(expense.type == .income ? InpensoTheme.positive : InpensoTheme.ink)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var amountText: String {
        let formatted = expense.price.formatted(.currency(code: currencyCode))
        return expense.type == .income ? "+\(formatted)" : "−\(formatted)"
    }
}
