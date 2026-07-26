//
//  CardView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

/// Soft surface panel used in forms — Tide Ledger styling.
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
        VStack(alignment: titleAlignment, spacing: 12) {
            Text(title)
                .font(InpensoTheme.label(14, weight: .semibold))
                .foregroundStyle(InpensoTheme.slate)
                .padding(.horizontal)

            if showDivider {
                Divider()
                    .opacity(0.4)
                    .padding(.horizontal)
            }

            content
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(InpensoTheme.ink.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct SectionHeaderText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(InpensoTheme.label(13, weight: .semibold))
            .foregroundStyle(InpensoTheme.muted)
    }
}

#Preview {
    ZStack {
        AtmosphereBackground()
        VStack(spacing: 20) {
            CardView(title: "Basic Card") {
                Text("This is the content of the card")
                    .padding()
            }
        }
        .padding()
    }
}
