//
//  CategoryGrid.swift
//  iExpense
//

import SwiftUI

struct CategoryGrid: View {
    @Binding var selectedCategoryID: String
    let categories: [FinanceCategory]
    var onCategorySelected: (() -> Void)? = nil

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: InpensoTheme.Space.md) {
            ForEach(categories) { category in
                CategoryButton(
                    category: category,
                    isSelected: selectedCategoryID == category.id,
                    action: {
                        withAnimation(InpensoTheme.Motion.snappy) {
                            selectedCategoryID = category.id
                        }
                        HapticFeedback.impact()
                        onCategorySelected?()
                    }
                )
            }
        }
        .padding(.horizontal, InpensoTheme.Space.md)
        .padding(.bottom, InpensoTheme.Space.xs)
    }
}

struct CategoryGridWithCallback: View {
    let selectedCategoryID: String
    let categories: [FinanceCategory]
    let onCategorySelected: (FinanceCategory) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: InpensoTheme.Space.md) {
            ForEach(categories) { category in
                CategoryButton(
                    category: category,
                    isSelected: selectedCategoryID == category.id,
                    action: {
                        HapticFeedback.impact()
                        onCategorySelected(category)
                    }
                )
            }
        }
        .padding(.horizontal, InpensoTheme.Space.md)
        .padding(.bottom, InpensoTheme.Space.xs)
    }
}

#Preview {
    ZStack {
        AtmosphereBackground()
        CategoryGrid(
            selectedCategoryID: .constant(Category.food.categoryID),
            categories: FinanceCategory.builtInCategories
        )
        .padding(.vertical, InpensoTheme.Space.md)
        .inpensoPanelBackground()
        .padding(InpensoTheme.Space.screen)
    }
}
