//
//  InpensoTheme.swift
//  iExpense
//
//  Obsidian + Jade — calm stone canvas, charcoal hero cards, jade accent.
//

import SwiftUI

enum InpensoTheme {
    // MARK: - Palette

    /// Obsidian forest — text & hero base
    static let ink = Color(inpensoHex: "#0E1C1A")
    static let inkSoft = Color(inpensoHex: "#1A302C")
    /// Jade — links, selected chrome, Available today
    static let tide = Color(inpensoHex: "#0F9F74")
    static let tideSoft = Color(inpensoHex: "#C8F0DF")
    /// Soft mint highlight
    static let seafoam = Color(inpensoHex: "#3DDC97")
    /// Chip / quiet fill
    static let mist = Color(inpensoHex: "#E2EBE7")
    static let mistDeep = Color(inpensoHex: "#D0DDD8")
    /// App canvas — cool sage stone (not cream)
    static let foam = Color(inpensoHex: "#EEF3F1")
    static let foamDeep = Color(inpensoHex: "#E4EDE9")
    /// Primary CTA
    static let copper = Color(inpensoHex: "#0E1C1A")
    static let copperSoft = Color(inpensoHex: "#2A453F")
    static let slate = Color(inpensoHex: "#3D544E")
    static let muted = Color(inpensoHex: "#6E817A")
    /// Coral — expense
    static let danger = Color(inpensoHex: "#E85A4F")
    /// Jade green — income
    static let surplus = Color(inpensoHex: "#0F9F74")
    static let hairline = Color(inpensoHex: "#D3DFDA")
    static let panelFill = Color.white
    /// Warm highlight for hero glow
    static let glow = Color(inpensoHex: "#7CFFC4")

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
        .system(size: 13, weight: .bold, design: .rounded)
    }
}

// MARK: - Canvas

struct AtmosphereBackground: View {
    var intensity: Double = 1.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    InpensoTheme.foam,
                    InpensoTheme.foamDeep
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft jade glow — top trailing
            Circle()
                .fill(InpensoTheme.glow.opacity(0.14 * intensity))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: 130, y: -80)

            // Quiet mist — bottom leading
            Circle()
                .fill(InpensoTheme.tide.opacity(0.06 * intensity))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -140, y: 420)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Banking hero surface

struct BankingHeroBackground: View {
    var radius: CGFloat = InpensoTheme.Radius.hero

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        InpensoTheme.ink,
                        Color(inpensoHex: "#143029"),
                        InpensoTheme.inkSoft
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(InpensoTheme.glow.opacity(0.18))
                    .frame(width: 140, height: 140)
                    .blur(radius: 36)
                    .offset(x: 28, y: -34)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(InpensoTheme.tide.opacity(0.22))
                    .frame(width: 110, height: 110)
                    .blur(radius: 28)
                    .offset(x: -30, y: 36)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: InpensoTheme.ink.opacity(0.22), radius: 20, y: 10)
    }
}

struct BankingPeriodChips: View {
    @Binding var selection: LedgerDateSelection
    var modes: [LedgerRangeMode] = LedgerRangeMode.allCases
    var onDark: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            ForEach(modes) { mode in
                let selected = selection.mode == mode
                Button {
                    HapticFeedback.selection()
                    withAnimation(InpensoTheme.Motion.snappy) {
                        selection.mode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(chipForeground(selected: selected))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(chipFill(selected: selected))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private func chipForeground(selected: Bool) -> Color {
        if onDark {
            return selected ? InpensoTheme.ink : .white.opacity(0.88)
        }
        return selected ? .white : InpensoTheme.slate
    }

    private func chipFill(selected: Bool) -> Color {
        if onDark {
            return selected ? Color.white : Color.white.opacity(0.12)
        }
        return selected ? InpensoTheme.ink : InpensoTheme.mist
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
                    .shadow(color: InpensoTheme.ink.opacity(0.05), radius: 14, y: 5)
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
                .shadow(color: InpensoTheme.ink.opacity(0.05), radius: 14, y: 5)
        )
    }

    func reveal(_ visible: Bool, delay: Double = 0) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .animation(InpensoTheme.Motion.reveal.delay(delay), value: visible)
    }
}
