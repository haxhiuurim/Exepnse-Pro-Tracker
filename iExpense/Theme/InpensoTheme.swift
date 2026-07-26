//
//  InpensoTheme.swift
//  iExpense
//
//  Tide Ledger — deep teal ink, mist atmosphere, copper action.
//  Spacing, radius, and motion tokens keep every screen consistent.
//

import SwiftUI

enum InpensoTheme {
    // MARK: - Brand palette

    static let ink = Color(inpensoHex: "#0C3B3A")
    static let inkSoft = Color(inpensoHex: "#1A5553")
    static let tide = Color(inpensoHex: "#2A8F87")
    static let seafoam = Color(inpensoHex: "#7BC4B8")
    static let mist = Color(inpensoHex: "#E8F1EF")
    static let mistDeep = Color(inpensoHex: "#D4E6E2")
    static let foam = Color(inpensoHex: "#F4FAF8")
    static let copper = Color(inpensoHex: "#C96A3D")
    static let copperSoft = Color(inpensoHex: "#E08A5E")
    static let slate = Color(inpensoHex: "#3D4F4E")
    static let muted = Color(inpensoHex: "#6B7F7D")
    static let danger = Color(inpensoHex: "#C44536")
    static let surplus = Color(inpensoHex: "#1F7A4D")

    // MARK: - Semantic

    static var brand: Color { ink }
    static var accent: Color { copper }
    static var positive: Color { surplus }
    static var negative: Color { danger }
    static var surface: Color { foam }
    static var surfaceElevated: Color { Color.white.opacity(0.78) }
    static var textPrimary: Color { ink }
    static var textSecondary: Color { muted }

    // MARK: - Spacing scale (4pt base)

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
        static let bottomClearance: CGFloat = 108
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
        static let hero: CGFloat = 28
    }

    enum Motion {
        static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.82)
        static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.86)
        static let reveal = Animation.spring(response: 0.6, dampingFraction: 0.84)
    }

    // MARK: - Typography

    static func brandFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func displayAmount(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func label(_ size: CGFloat = 13, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func sectionLabel() -> Font {
        label(12, weight: .bold)
    }
}

// MARK: - Atmosphere background

struct AtmosphereBackground: View {
    var intensity: Double = 1.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    InpensoTheme.foam,
                    InpensoTheme.mist,
                    InpensoTheme.mistDeep.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            InpensoTheme.tide.opacity(0.16 * intensity),
                            InpensoTheme.tide.opacity(0)
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 300
                    )
                )
                .frame(width: 440, height: 440)
                .offset(x: -130, y: -200)
                .blur(radius: 10)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            InpensoTheme.copper.opacity(0.10 * intensity),
                            InpensoTheme.copper.opacity(0)
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 240
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: 150, y: 340)
                .blur(radius: 14)

            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 32
                    var y: CGFloat = 72
                    while y < geo.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += spacing
                    }
                }
                .stroke(InpensoTheme.ink.opacity(0.025), lineWidth: 1)
            }
        }
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
            Text(title.uppercased())
                .font(InpensoTheme.sectionLabel())
                .foregroundStyle(InpensoTheme.muted)
                .tracking(1.1)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(InpensoTheme.label(12, weight: .bold))
                    .foregroundStyle(InpensoTheme.copper)
            }
        }
    }
}

// MARK: - Surface panel

struct SurfacePanel<Content: View>: View {
    var padding: CGFloat = InpensoTheme.Space.md
    var radius: CGFloat = InpensoTheme.Radius.xl
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(InpensoTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(InpensoTheme.ink.opacity(0.055), lineWidth: 1)
                    )
                    .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 12, y: 4)
            )
    }
}

// MARK: - Buttons

struct InpensoPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InpensoTheme.label(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(
                        enabled
                            ? LinearGradient(
                                colors: [InpensoTheme.copper, InpensoTheme.copperSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [InpensoTheme.muted.opacity(0.4), InpensoTheme.muted.opacity(0.32)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .shadow(
                        color: enabled ? InpensoTheme.copper.opacity(configuration.isPressed ? 0.15 : 0.28) : .clear,
                        radius: configuration.isPressed ? 4 : 10,
                        y: configuration.isPressed ? 2 : 5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct InpensoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InpensoTheme.label(15, weight: .semibold))
            .foregroundStyle(InpensoTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(Color.white.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                            .stroke(InpensoTheme.ink.opacity(0.14), lineWidth: 1.25)
                    )
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Period chips

struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : InpensoTheme.slate)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? InpensoTheme.ink : InpensoTheme.ink.opacity(0.055))
                )
        }
        .buttonStyle(.plain)
        .animation(InpensoTheme.Motion.snappy, value: isSelected)
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
            .offset(y: visible ? 0 : 14)
            .animation(InpensoTheme.Motion.reveal.delay(delay), value: visible)
    }
}
