//
//  PaywallView.swift
//  iExpense
//
//  Primary Pro offering — yearly (50% off) + monthly.
//

import SwiftUI

struct PaywallView: View {
    @ObservedObject var pro: ProEntitlementManager
    var initialPlan: ProPlan = .yearly
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selected: ProPlan = .yearly
    @State private var appeared = false

    private let features: [(icon: String, title: String, detail: String)] = [
        ("doc.text.viewfinder", "Unlimited receipt scans", "OCR every grocery run — no monthly cap"),
        ("icloud.fill", "iCloud sync", "Keep every device in lockstep"),
        ("chart.bar.doc.horizontal", "Advanced widgets & Live Activities", "Dynamic Island spent-today pulse"),
        ("tag.fill", "Unlimited category budgets", "Alerts when a category runs hot"),
        ("arrow.triangle.2.circlepath", "Unlimited recurring + calendar", "See what’s due this month"),
        ("square.and.arrow.up", "CSV / OFX export", "Accountant-ready reports"),
        ("target", "Savings goals & envelopes", "Give every dollar a job"),
        ("person.2.fill", "Shared household ledger", "Invite a partner, split categories"),
        ("paintpalette.fill", "Themes & icons", "Make Inpenso yours"),
        ("bolt.horizontal.fill", "Merchant rules", "Uber → Transport, automatically"),
        ("building.columns.fill", "Accounts & net worth", "Cash, cards, light balances")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        InpensoTheme.ink,
                        InpensoTheme.inkSoft,
                        Color(inpensoHex: "#0F5C56")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(InpensoTheme.copper.opacity(0.2))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 140, y: -220)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.xl) {
                        header
                        planCards
                        featureList
                        legalFooter
                    }
                    .padding(.horizontal, InpensoTheme.Space.lg)
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, 120)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: InpensoTheme.Space.sm) {
                        ctaButton
                        restoreRow
                    }
                    .padding(.horizontal, InpensoTheme.Space.lg)
                    .padding(.top, InpensoTheme.Space.md)
                    .padding(.bottom, InpensoTheme.Space.sm)
                    .background(
                        LinearGradient(
                            colors: [
                                InpensoTheme.ink.opacity(0),
                                InpensoTheme.ink.opacity(0.92),
                                InpensoTheme.ink
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onDismiss?()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.white.opacity(0.12)))
                    }
                }
            }
            .alert("Purchase issue", isPresented: Binding(
                get: { pro.lastError != nil },
                set: { if !$0 { pro.lastError = nil } }
            )) {
                Button("OK", role: .cancel) { pro.lastError = nil }
            } message: {
                Text(pro.lastError ?? "")
            }
            .onAppear {
                selected = initialPlan == .yearlySpecial ? .yearly : initialPlan
                withAnimation(InpensoTheme.Motion.gentle) {
                    appeared = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text("INPENSO PRO")
                .font(InpensoTheme.label(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(InpensoTheme.seafoam)

            Text("Your ledger,\nunlocked.")
                .font(InpensoTheme.brandFont(34, weight: .bold))
                .foregroundStyle(.white)
                .lineSpacing(2)

            Text("No ads. Private on-device power — with Pro tools when you need them.")
                .font(InpensoTheme.body(15))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, InpensoTheme.Space.xs)
    }

    private var planCards: some View {
        VStack(spacing: InpensoTheme.Space.sm) {
            planCard(.yearly)
            planCard(.monthly)
        }
    }

    private func planCard(_ plan: ProPlan) -> some View {
        let isSelected = selected == plan
        return Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selected = plan
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? InpensoTheme.copperSoft : .white.opacity(0.25), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(InpensoTheme.copper)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(plan.title)
                            .font(InpensoTheme.body(17, weight: .bold))
                            .foregroundStyle(.white)
                        if plan == .yearly {
                            Text("BEST VALUE")
                                .font(InpensoTheme.label(10, weight: .bold))
                                .foregroundStyle(InpensoTheme.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(InpensoTheme.seafoam, in: Capsule())
                        }
                        Spacer()
                    }

                    Text(plan.subtitle)
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(.white.opacity(0.6))

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let strike = plan.strikethroughPrice {
                            Text(strike)
                                .font(InpensoTheme.body(15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                                .strikethrough(true, color: .white.opacity(0.45))
                        }
                        Text(pro.priceText(for: plan))
                            .font(InpensoTheme.displayAmount(28))
                            .foregroundStyle(.white)
                        Text(plan == .monthly ? "/ mo" : "/ yr")
                            .font(InpensoTheme.label(13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    if let weekly = plan.weeklyEquivalent {
                        Text("That’s \(weekly)/week")
                            .font(InpensoTheme.label(12, weight: .semibold))
                            .foregroundStyle(InpensoTheme.seafoam)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.14 : 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isSelected ? InpensoTheme.copper.opacity(0.7) : .white.opacity(0.08),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var ctaButton: some View {
        Button {
            Task {
                _ = await pro.purchase(selected)
            }
        } label: {
            HStack {
                if pro.purchaseInFlight {
                    ProgressView().tint(InpensoTheme.ink)
                }
                Text(selected == .yearly ? "Start yearly · \(pro.priceText(for: .yearly))" : "Start monthly · \(pro.priceText(for: .monthly))")
                    .font(InpensoTheme.label(16, weight: .bold))
            }
            .foregroundStyle(InpensoTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(
                    colors: [InpensoTheme.seafoam, Color(inpensoHex: "#A8E6DC")],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .disabled(pro.purchaseInFlight)
    }

    private var restoreRow: some View {
        Button("Restore purchases") {
            Task { await pro.restore() }
        }
        .font(InpensoTheme.label(13, weight: .semibold))
        .foregroundStyle(.white.opacity(0.65))
        .frame(maxWidth: .infinity)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            Text("EVERYTHING IN PRO")
                .font(InpensoTheme.label(11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.45))

            ForEach(features, id: \.title) { feature in
                HStack(alignment: .top, spacing: InpensoTheme.Space.sm) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(InpensoTheme.seafoam)
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(InpensoTheme.body(14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(feature.detail)
                            .font(InpensoTheme.label(12))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                }
            }
        }
    }

    private var legalFooter: some View {
        Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage in Settings → Apple ID. No ads — ever.")
            .font(InpensoTheme.label(11))
            .foregroundStyle(.white.opacity(0.38))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Special 60% offer

struct SpecialOfferPaywallView: View {
    @ObservedObject var pro: ProEntitlementManager
    @Environment(\.dismiss) private var dismiss
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [InpensoTheme.copper, InpensoTheme.copperSoft, Color(inpensoHex: "#F0A070")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 140)
                .overlay(alignment: .topTrailing) {
                    Button {
                        dismiss()
                        pro.showSpecialOffer = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(.black.opacity(0.25)))
                    }
                    .padding(14)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LIMITED OFFER")
                            .font(InpensoTheme.label(11, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("60% off yearly")
                            .font(InpensoTheme.brandFont(28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(20)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("$29.99")
                            .font(InpensoTheme.body(18, weight: .semibold))
                            .foregroundStyle(InpensoTheme.muted)
                            .strikethrough()
                        Text(pro.priceText(for: .yearlySpecial))
                            .font(InpensoTheme.displayAmount(40))
                            .foregroundStyle(InpensoTheme.ink)
                            .scaleEffect(pulse ? 1.03 : 1)
                        Text("/ year")
                            .font(InpensoTheme.label(14, weight: .semibold))
                            .foregroundStyle(InpensoTheme.muted)
                    }

                    Text("That’s \(ProPlan.yearlySpecial.weeklyEquivalent ?? "$0.23")/week — unlock every Pro tool with no ads.")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.slate)

                    VStack(alignment: .leading, spacing: 8) {
                        offerBullet("Unlimited OCR, sync & widgets")
                        offerBullet("Goals, accounts, merchant rules")
                        offerBullet("Shared ledger & exports")
                    }

                    Button {
                        Task {
                            _ = await pro.purchase(.yearlySpecial)
                        }
                    } label: {
                        HStack {
                            if pro.purchaseInFlight { ProgressView().tint(.white) }
                            Text("Claim 60% off")
                                .font(InpensoTheme.label(16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [InpensoTheme.copper, InpensoTheme.copperSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .disabled(pro.purchaseInFlight)

                    Button("See all plans") {
                        dismiss()
                        pro.showSpecialOffer = false
                        pro.openPaywall(plan: .yearly)
                    }
                    .font(InpensoTheme.label(13, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
                    .frame(maxWidth: .infinity)
                }
                .padding(22)
                .background(InpensoTheme.foam)
            }
            .clipShape(RoundedRectangle(cornerRadius: InpensoTheme.Radius.hero, style: .continuous))
            .padding(.horizontal, InpensoTheme.Space.lg)
            .shadow(color: .black.opacity(0.28), radius: 28, y: 14)
            .padding(.vertical, InpensoTheme.Space.xl)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func offerBullet(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(InpensoTheme.tide)
            Text(text)
                .font(InpensoTheme.body(13, weight: .medium))
                .foregroundStyle(InpensoTheme.ink)
        }
    }
}

struct UpgradePillButton: View {
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: compact ? 10 : 12, weight: .bold))
                Text(compact ? "Pro" : "Upgrade")
                    .font(InpensoTheme.label(compact ? 11 : 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 11 : 14)
            .padding(.vertical, compact ? 7 : 9)
            .background(
                LinearGradient(
                    colors: [InpensoTheme.copper, InpensoTheme.copperSoft],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule(style: .continuous)
            )
            .shadow(color: InpensoTheme.copper.opacity(0.3), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct ProGateBanner: View {
    let message: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(InpensoTheme.copper)
                    .frame(width: 32, height: 32)
                    .background(InpensoTheme.copper.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(message)
                        .font(InpensoTheme.body(13, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Upgrade to Pro")
                        .font(InpensoTheme.label(12, weight: .bold))
                        .foregroundStyle(InpensoTheme.copper)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(InpensoTheme.Space.md - 2)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(InpensoTheme.copper.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                            .stroke(InpensoTheme.copper.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
