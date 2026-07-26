//
//  CategoryButton.swift
//  iExpense
//

import SwiftUI

struct CategoryButton: View {
    let category: FinanceCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: InpensoTheme.Space.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                        .fill(isSelected ? category.color : InpensoTheme.mist)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                                .stroke(isSelected ? category.color : InpensoTheme.hairline, lineWidth: 1)
                        )

                    Image(systemName: category.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : category.color)
                }

                Text(category.displayName)
                    .font(InpensoTheme.label(10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? InpensoTheme.ink : InpensoTheme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 26)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: InpensoTheme.Space.lg) {
        CategoryButton(
            category: FinanceCategory.builtIn(for: .food),
            isSelected: true,
            action: {}
        )
        CategoryButton(
            category: FinanceCategory.builtIn(for: .transportation),
            isSelected: false,
            action: {}
        )
    }
    .padding(InpensoTheme.Space.screen)
    .background(InpensoTheme.foam)
}
