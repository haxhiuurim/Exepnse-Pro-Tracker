//
//  InpensoTheme.swift
//  iExpense
//
//  Field Notes — stark utility finance UI.
//  White canvas, charcoal type, vermillion actions. No orbs, no glow, no marketing fluff.
//

import SwiftUI

enum InpensoTheme {
    // MARK: - Palette

    /// Charcoal — text, selected chrome
    static let ink = Color(inpensoHex: "#171717")
    static let inkSoft = Color(inpensoHex: "#262626")
    /// Sky — charts / links only
    static let tide = Color(inpensoHex: "#0284C7")
    /// Deep teal — income
    static let seafoam = Color(inpensoHex: "#0F766E")
    /// Quiet section fill
    static let mist = Color(inpensoHex: "#F0F0EE")
    static let mistDeep = Color(inpensoHex: "#E4E4E1")
    /// App canvas
    static let foam = Color(inpensoHex: "#F7F7F5")
    /// Primary solid action (matches charcoal — deliberate, not candy)
    static let copper = Color(inpensoHex: "#171717")
    static let copperSoft = Color(inpensoHex: "#404040")
    static let slate = Color(inpensoHex: "#404040")
    static let muted = Color(inpensoHex: "#737373")
    /// Vermillion — expense / destructive
    static let danger = Color(inpensoHex: "#E03E2F")
    /// Income / positive
    static let surplus = Color(inpensoHex: "#0F766E")
    static let hairline = Color(inpensoHex: "#E5E5E5")
    static let panelFill = Color.white

    // MARK: - Semantic

    static var brand: Color { ink }
    static var accent: Color { ink }
    static var positive: Color { surplus }
    static var negative: Color { danger }
    static var chart: Color { tide }
    static var surface: Color { foam }
    static var surfaceElevated: Color { panelFill }
    static var textPrimary: Color { ink }
    static var textSecondary: Color { muted }
    static var expenseTint: Color { danger }
    static var incomeTint: Color { surplus }

    // MARK: - Spacing

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        /// Horizontal page gutter — always apply on screen content
        static let screen: CGFloat = 24
        static let section: CGFloat = 32
        static let bottomClearance: CGFloat = 128
        static let row: CGFloat = 16
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 14
        static let hero: CGFloat = 16
    }

    enum Motion {
        static let snappy = Animation.easeOut(duration: 0.16)
        static let gentle = Animation.easeInOut(duration: 0.24)
        static let reveal = Animation.easeOut(duration: 0.28)
    }

    // MARK: - Type

    static func brandFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func displayAmount(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func label(_ size: CGFloat = 13, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func sectionLabel() -> Font {
        .system(size: 15, weight: .semibold, design: .default)
    }
}

// MARK: - Canvas

struct AtmosphereBackground: View {
    var intensity: Double = 1.0

    var body: some View {
        InpensoTheme.foam
            .ignoresSafeArea()
    }
}

// MARK: - Section header

struct InpensoSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(InpensoTheme.sectionLabel())
                .foregroundStyle(InpensoTheme.ink)
            Spacer(minLength: InpensoTheme.Space.sm)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(InpensoTheme.label(14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
            }
        }
    }
}

// MARK: - Surface (flat white block — use sparingly)

struct SurfacePanel<Content: View>: View {
    var padding: CGFloat = InpensoTheme.Space.md
    var radius: CGFloat = InpensoTheme.Radius.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )
    }
}

// MARK: - Buttons

struct InpensoPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    var tint: Color = InpensoTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InpensoTheme.body(16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, InpensoTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(enabled ? tint : InpensoTheme.muted.opacity(0.35))
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

struct InpensoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InpensoTheme.body(16, weight: .semibold))
            .foregroundStyle(InpensoTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, InpensoTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(InpensoTheme.mist)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

// MARK: - Expense / Income

struct TransactionTypePicker: View {
    @Binding var type: TransactionType

    var body: some View {
        HStack(spacing: InpensoTheme.Space.xs) {
            typeButton(.expense, title: "Expense", color: InpensoTheme.expenseTint)
            typeButton(.income, title: "Income", color: InpensoTheme.incomeTint)
        }
    }

    private func typeButton(_ value: TransactionType, title: String, color: Color) -> some View {
        let selected = type == value
        return Button {
            HapticFeedback.selection()
            withAnimation(InpensoTheme.Motion.snappy) { type = value }
        } label: {
            Text(title)
                .font(InpensoTheme.body(15, weight: .semibold))
                .foregroundStyle(selected ? .white : InpensoTheme.slate)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                        .fill(selected ? color : InpensoTheme.mist)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Period

struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(InpensoTheme.label(14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : InpensoTheme.slate)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        .fill(isSelected ? InpensoTheme.ink : InpensoTheme.mist)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PeriodSelector: View {
    @Binding var period: SpendingPeriod

    var body: some View {
        HStack(spacing: InpensoTheme.Space.xs) {
            ForEach(SpendingPeriod.allCases) { item in
                PeriodChip(title: item.shortTitle, isSelected: period == item) {
                    HapticFeedback.selection()
                    withAnimation(InpensoTheme.Motion.snappy) {
                        period = item
                    }
                }
            }
        }
    }
}

extension Color {
    init(inpensoHex hex: String) {
        self = Color(hex: hex) ?? .black
    }
}

extension View {
    func inpensoScreenPadding() -> some View {
        padding(.horizontal, InpensoTheme.Space.screen)
    }

    func reveal(_ visible: Bool, delay: Double = 0) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .animation(InpensoTheme.Motion.reveal.delay(delay), value: visible)
    }
}
