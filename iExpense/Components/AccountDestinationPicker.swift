//
//  AccountDestinationPicker.swift
//  iExpense
//
//  Lets the user choose which liquid account receives income.
//

import SwiftUI

struct AccountDestinationPicker: View {
    @ObservedObject private var store = PremiumDataStore.shared
    @Binding var selectedAccountID: UUID?
    var currencyCode: String

    private var liquidAccounts: [FinanceAccount] {
        store.accounts.filter(\.isLiquid)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text("Deposit to")
                .font(InpensoTheme.label(12, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
                .textCase(.uppercase)

            if liquidAccounts.isEmpty {
                Text("Add an account in More → Accounts first.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                    .padding(InpensoTheme.Space.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                            .fill(InpensoTheme.mist)
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(liquidAccounts) { account in
                        let selected = selectedAccountID == account.id
                        Button {
                            selectedAccountID = account.id
                            HapticFeedback.selection()
                        } label: {
                            HStack(spacing: InpensoTheme.Space.sm) {
                                Image(systemName: account.kind.iconName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(selected ? .white : InpensoTheme.tide)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        (selected ? Color.white.opacity(0.2) : InpensoTheme.tide.opacity(0.12)),
                                        in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                        .font(InpensoTheme.body(15, weight: .semibold))
                                        .foregroundStyle(selected ? .white : InpensoTheme.ink)
                                    Text(account.kind.displayName)
                                        .font(InpensoTheme.label(11))
                                        .foregroundStyle(selected ? .white.opacity(0.8) : InpensoTheme.muted)
                                }

                                Spacer()

                                Text(account.balance, format: .currency(code: currencyCode))
                                    .font(InpensoTheme.displayAmount(13))
                                    .foregroundStyle(selected ? .white : InpensoTheme.slate)

                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(selected ? .white : InpensoTheme.muted.opacity(0.5))
                            }
                            .padding(InpensoTheme.Space.md)
                            .background(
                                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                                    .fill(selected ? InpensoTheme.incomeTint : InpensoTheme.mist)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            if selectedAccountID == nil {
                selectedAccountID = store.primaryLiquidAccount?.id ?? liquidAccounts.first?.id
            }
        }
    }
}
