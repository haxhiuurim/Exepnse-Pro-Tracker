//
//  InpensoTheme.swift
//  iExpense
//
//  Tide Ledger — deep teal ink, mist atmosphere, copper action.
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
    static var surfaceElevated: Color { Color.white.opacity(0.72) }
    static var textPrimary: Color { ink }
    static var textSecondary: Color { muted }

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
                    InpensoTheme.mistDeep.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft tide wash — top-left
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            InpensoTheme.tide.opacity(0.18 * intensity),
                            InpensoTheme.tide.opacity(0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 280
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: -120, y: -180)
                .blur(radius: 8)

            // Copper warmth — bottom-right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            InpensoTheme.copper.opacity(0.12 * intensity),
                            InpensoTheme.copper.opacity(0)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .frame(width: 340, height: 340)
                .offset(x: 140, y: 320)
                .blur(radius: 12)

            // Subtle ledger lines pattern
            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 28
                    var y: CGFloat = 60
                    while y < geo.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += spacing
                    }
                }
                .stroke(InpensoTheme.ink.opacity(0.03), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Surface panel (not a generic card — soft glass plane)

struct SurfacePanel<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(InpensoTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(InpensoTheme.ink.opacity(0.06), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Primary CTA button style

struct InpensoPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InpensoTheme.label(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        enabled
                            ? LinearGradient(
                                colors: [InpensoTheme.copper, InpensoTheme.copperSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [InpensoTheme.muted.opacity(0.45), InpensoTheme.muted.opacity(0.35)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct InpensoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InpensoTheme.label(15, weight: .semibold))
            .foregroundStyle(InpensoTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(InpensoTheme.ink.opacity(0.18), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(InpensoTheme.foam.opacity(0.6))
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Period chip

struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : InpensoTheme.slate)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? InpensoTheme.ink : InpensoTheme.ink.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isSelected)
    }
}

struct PeriodSelector: View {
    @Binding var period: SpendingPeriod

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SpendingPeriod.allCases) { item in
                PeriodChip(title: item.shortTitle, isSelected: period == item) {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
