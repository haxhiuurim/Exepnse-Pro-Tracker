//
//  FormFields.swift
//  iExpense
//

import SwiftUI

struct TextFormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var leadingIcon: String? = nil
    var trailingIcon: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
            Text(label.uppercased())
                .font(InpensoTheme.label(11, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)

            HStack(spacing: InpensoTheme.Space.sm) {
                if let iconName = leadingIcon {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(InpensoTheme.muted)
                        .frame(width: 18)
                }

                TextField(placeholder, text: $text)
                    .font(InpensoTheme.body(16))
                    .foregroundStyle(InpensoTheme.ink)
                    .keyboardType(keyboardType)
                    .tint(InpensoTheme.copper)

                if let iconName = trailingIcon {
                    Button { trailingAction?() } label: {
                        Image(systemName: iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(InpensoTheme.muted)
                    }
                    .disabled(trailingAction == nil)
                }
            }
            .padding(.horizontal, InpensoTheme.Space.md)
            .padding(.vertical, InpensoTheme.Space.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(InpensoTheme.mist)
            )
        }
    }
}

struct CurrencyFormField: View {
    let label: String
    @Binding var amount: String
    var currencySymbol: String
    var clearAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
            if !label.isEmpty {
                Text(label.uppercased())
                    .font(InpensoTheme.label(11, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
            }

            HStack(alignment: .firstTextBaseline, spacing: InpensoTheme.Space.xs) {
                Text(currencySymbol)
                    .font(InpensoTheme.displayAmount(20))
                    .foregroundStyle(InpensoTheme.muted)

                TextField("0.00", text: $amount)
                    .font(InpensoTheme.displayAmount(32))
                    .foregroundStyle(InpensoTheme.ink)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .tint(InpensoTheme.copper)
                    .onChange(of: amount) {
                        amount = formatCurrencyInput(amount)
                    }

                Spacer(minLength: 0)

                if !amount.isEmpty {
                    Button {
                        if let clearAction { clearAction() } else { amount = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(InpensoTheme.muted.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, InpensoTheme.Space.md)
            .padding(.vertical, InpensoTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(InpensoTheme.mist)
            )
        }
    }

    private func formatCurrencyInput(_ input: String) -> String {
        var formattedInput = input.replacingOccurrences(of: ",", with: ".")
        let components = formattedInput.components(separatedBy: ".")
        if components.count > 2 {
            formattedInput = components[0] + "." + components[1]
        }
        if let decimalIndex = formattedInput.firstIndex(of: ".") {
            let decimalPosition = formattedInput.distance(from: formattedInput.startIndex, to: decimalIndex)
            let maxLength = decimalPosition + 3
            if formattedInput.count > maxLength {
                let endIndex = formattedInput.index(formattedInput.startIndex, offsetBy: maxLength)
                formattedInput = String(formattedInput[..<endIndex])
            }
        }
        return formattedInput
    }
}

#Preview {
    ZStack {
        AtmosphereBackground()
        VStack(spacing: InpensoTheme.Space.xl) {
            TextFormField(
                label: "Title",
                text: .constant("Groceries"),
                placeholder: "Enter title",
                leadingIcon: "pencil"
            )
            CurrencyFormField(
                label: "Amount",
                amount: .constant("123.45"),
                currencySymbol: "$"
            )
        }
        .padding(InpensoTheme.Space.screen)
    }
}
