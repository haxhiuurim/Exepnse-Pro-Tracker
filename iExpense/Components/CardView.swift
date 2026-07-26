//
//  CardView.swift
//  iExpense
//

import SwiftUI

struct CardView<Content: View>: View {
    let title: String
    let content: Content
    var titleAlignment: HorizontalAlignment = .leading
    var showDivider: Bool = false

    init(
        title: String,
        titleAlignment: HorizontalAlignment = .leading,
        showDivider: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleAlignment = titleAlignment
        self.showDivider = showDivider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: titleAlignment, spacing: InpensoTheme.Space.md) {
            Text(title.uppercased())
                .font(InpensoTheme.label(11, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, InpensoTheme.Space.md)

            if showDivider {
                Divider()
                    .overlay(InpensoTheme.hairline)
                    .padding(.horizontal, InpensoTheme.Space.md)
            }

            content
        }
        .padding(.vertical, InpensoTheme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .stroke(InpensoTheme.hairline, lineWidth: 1)
                )
        )
    }
}

struct SectionHeaderText: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(InpensoTheme.label(11, weight: .semibold))
            .foregroundStyle(InpensoTheme.muted)
    }
}

#Preview {
    ZStack {
        AtmosphereBackground()
        CardView(title: "Details") {
            Text("Form content goes here")
                .font(InpensoTheme.body(15))
                .foregroundStyle(InpensoTheme.ink)
                .padding(.horizontal, InpensoTheme.Space.md)
        }
        .padding(InpensoTheme.Space.screen)
    }
}
