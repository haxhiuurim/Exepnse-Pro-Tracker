//
//  InpensoTheme.swift
//  iExpense
//
//  North — new-app visual system for Inpenso.
//  Soft blue canvas, navy type, cobalt accent. Quiet surfaces, clear money color.
//

import SwiftUI

enum InpensoTheme {
    // MARK: - Palette

    /// Deep navy — text & chrome
    static let ink = Color(inpensoHex: "#0B1B33")
    static let inkSoft = Color(inpensoHex: "#152A47")
    /// Cobalt — links, charts, selected chrome
    static let tide = Color(inpensoHex: "#3B6EF5")
    /// Soft mint highlight
    static let seafoam = Color(inpensoHex: "#34D399")
    /// Chip / quiet fill
    static let mist = Color(inpensoHex: "#E4EAF3")
    static let mistDeep = Color(inpensoHex: "#D5DEEB")
    /// App canvas
    static let foam = Color(inpensoHex: "#EEF1F6")
    /// Primary CTA (navy)
    static let copper = Color(inpensoHex: "#0B1B33")
    static let copperSoft = Color(inpensoHex: "#243B5C")
    static let slate = Color(inpensoHex: "#3A4A63")
    static let muted = Color(inpensoHex: "#6B7A90")
    /// Rose — expense
    static let danger = Color(inpensoHex: "#F0435D")
    /// Green — income
    static let surplus = Color(inpensoHex: "#12B981")
    static let hairline = Color(inpensoHex: "#D7DEEA")
    static let panelFill = Color.white

    // MARK: - Semantic

    static var brand: Color { ink }
    static var accent: Color { tide }
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
        static let screen: CGFloat = 20
        static let section: CGFloat = 28
        static let bottomClearance: CGFloat = 132
        static let row: CGFloat = 14
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let hero: CGFloat = 28
    }

    enum Motion {
        static let snappy = Animation.easeOut(duration: 0.18)
        static let gentle = Animation.easeInOut(duration: 0.26)
        static let reveal = Animation.easeOut(duration: 0.32)
    }

    // MARK: - Type

    static func brandFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func displayAmount(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func label(_ size: CGFloat = 13, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func sectionLabel() -> Font {
        .system(size: 14, weight: .bold, design: .rounded)
    }
}

// MARK: - Canvas

struct AtmosphereBackground: View {
    var intensity: Double = 1.0

    var body: some View {
        LinearGradient(
            colors: [
                InpensoTheme.foam,
                Color(inpensoHex: "#E8EDF6")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
                    .font(InpensoTheme.label(14, weight: .bold))
                    .foregroundStyle(InpensoTheme.tide)
            }
        }
    }
}

// MARK: - Surface

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
                    .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 12, y: 4)
            )
    }
}

// MARK: - Buttons

struct InpensoPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    var tint: Color = InpensoTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InpensoTheme.label(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.horizontal, InpensoTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(enabled ? tint : InpensoTheme.muted.opacity(0.35))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct InpensoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InpensoTheme.label(16, weight: .bold))
            .foregroundStyle(InpensoTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.horizontal, InpensoTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(InpensoTheme.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                            .stroke(InpensoTheme.hairline, lineWidth: 1.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Expense / Income

struct TransactionTypePicker: View {
    @Binding var type: TransactionType

    var body: some View {
        HStack(spacing: 0) {
            typeButton(.expense, title: "Expense", color: InpensoTheme.expenseTint)
            typeButton(.income, title: "Income", color: InpensoTheme.incomeTint)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                .fill(InpensoTheme.mist)
        )
    }

    private func typeButton(_ value: TransactionType, title: String, color: Color) -> some View {
        let selected = type == value
        return Button {
            HapticFeedback.selection()
            withAnimation(InpensoTheme.Motion.snappy) { type = value }
        } label: {
            Text(title)
                .font(InpensoTheme.label(14, weight: .bold))
                .foregroundStyle(selected ? .white : InpensoTheme.slate)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        .fill(selected ? color : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Period (underline tabs)

struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(InpensoTheme.label(15, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? InpensoTheme.ink : InpensoTheme.muted)
                Capsule()
                    .fill(isSelected ? InpensoTheme.tide : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct PeriodSelector: View {
    @Binding var period: SpendingPeriod

    var body: some View {
        HStack(spacing: InpensoTheme.Space.md) {
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

    func inpensoPanelBackground(radius: CGFloat = InpensoTheme.Radius.lg) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 12, y: 4)
        )
    }

    func reveal(_ visible: Bool, delay: Double = 0) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .animation(InpensoTheme.Motion.reveal.delay(delay), value: visible)
    }
}
