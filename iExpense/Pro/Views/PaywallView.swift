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

    private let features: [(icon: String, title: String, detail: String)] = [
        ("sun.max.fill", "Available Today depth", "Forecasts, alerts, and unlimited budgets"),
        ("doc.text.viewfinder", "Receipt scans", "OCR without a monthly cap"),
        ("icloud.fill", "Encrypted iCloud sync", "Optional backup — personal ledger stays private"),
        ("chart.bar.doc.horizontal", "Full Insights", "Trends, patterns, heatmap, projections"),
        ("creditcard.fill", "Subscriptions", "Unlimited recurring & burn alerts"),
        ("tag.fill", "Tags & categories", "Unlimited tags and custom categories"),
        ("square.and.arrow.up", "CSV / OFX / PDF", "Export for taxes and records"),
        ("target", "Savings goals", "Track targets and envelopes"),
        ("bolt.horizontal.fill", "Custom merchant rules", "Auto-categorize by payee name"),
        ("widget.small", "Live Activities", "Spent Today on Lock Screen")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                InpensoTheme.foam.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.xl) {
                        header
                        planCards
                        featureList
                        legalFooter
                    }
                    .inpensoScreenPadding()
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, 120)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: InpensoTheme.Space.sm) {
                        ctaButton
                        restoreRow
                    }
                    .inpensoScreenPadding()
                    .padding(.top, InpensoTheme.Space.md)
                    .padding(.bottom, InpensoTheme.Space.sm)
                    .background(
                        InpensoTheme.foam
                            .overlay(alignment: .top) {
                                Rectangle()
                                    .fill(InpensoTheme.hairline)
                                    .frame(height: 1)
                            }
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(InpensoTheme.ink)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                    .fill(InpensoTheme.mist)
                            )
                    }
                }
            }
            .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Purchase issue", isPresented: Binding(
                get: { pro.lastError != nil },
                set: { if !$0 { pro.lastError = nil } }
            )) {
                Button("OK", role: .cancel) { pro.lastError = nil }
            } message: {
                Text(pro.lastError ?? "")
            }
            .onAppear {
                if initialPlan == .yearlySpecial {
                    selected = .yearly
                } else {
                    selected = initialPlan
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text(AppBrand.proName)
                .font(InpensoTheme.label(12, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
                .textCase(.uppercase)

            Text("Pro tools for your ledger")
                .font(InpensoTheme.brandFont(28, weight: .bold))
                .foregroundStyle(InpensoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("No ads. Personal expenses stay on device. Trips use an optional server when you opt in. Subscribe for sync, exports, and advanced tools.")
                .font(InpensoTheme.body(15))
                .foregroundStyle(InpensoTheme.slate)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, InpensoTheme.Space.xs)
    }

    private var planCards: some View {
        VStack(spacing: InpensoTheme.Space.sm) {
            planCard(.yearly)
            planCard(.monthly)
            planCard(.lifetime)
        }
    }

    private func planCard(_ plan: ProPlan) -> some View {
        let isSelected = selected == plan
        return Button {
            HapticFeedback.selection()
            withAnimation(InpensoTheme.Motion.snappy) {
                selected = plan
            }
        } label: {
            HStack(alignment: .top, spacing: InpensoTheme.Space.sm) {
                selectionIndicator(isSelected: isSelected)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(plan.title)
                            .font(InpensoTheme.body(17, weight: .semibold))
                            .foregroundStyle(InpensoTheme.ink)
                        if plan == .yearly {
                            Text("· saves 50%")
                                .font(InpensoTheme.label(13))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                        Spacer()
                    }

                    Text(plan.subtitle)
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let strike = plan.strikethroughPrice {
                            Text(strike)
                                .font(InpensoTheme.body(15, weight: .medium))
                                .foregroundStyle(InpensoTheme.muted)
                                .strikethrough(true, color: InpensoTheme.muted)
                        }
                        Text(pro.priceText(for: plan))
                            .font(InpensoTheme.displayAmount(26))
                            .foregroundStyle(InpensoTheme.ink)
                        Text(plan == .monthly ? "/ mo" : plan == .lifetime ? " once" : "/ yr")
                            .font(InpensoTheme.label(13, weight: .medium))
                            .foregroundStyle(InpensoTheme.muted)
                    }

                    if let weekly = plan.weeklyEquivalent {
                        Text("\(weekly)/week")
                            .font(InpensoTheme.label(12))
                            .foregroundStyle(InpensoTheme.muted)
                    }
                }
            }
            .padding(InpensoTheme.Space.md)
            .background(planCardBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelected ? InpensoTheme.tide : InpensoTheme.hairline, lineWidth: isSelected ? 2 : 1)
                .frame(width: 22, height: 22)
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(InpensoTheme.tide)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private func planCardBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
            .fill(InpensoTheme.panelFill)
            .shadow(color: InpensoTheme.ink.opacity(isSelected ? 0.08 : 0.04), radius: 12, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .stroke(isSelected ? InpensoTheme.tide : Color.clear, lineWidth: 1.5)
            )
    }

    private var ctaButton: some View {
        Button {
            Task {
                _ = await pro.purchase(selected)
            }
        } label: {
            HStack {
                if pro.purchaseInFlight {
                    ProgressView().tint(.white)
                }
                Text(ctaTitle)
            }
        }
        .buttonStyle(InpensoPrimaryButtonStyle(enabled: !pro.purchaseInFlight, tint: InpensoTheme.tide))
        .disabled(pro.purchaseInFlight)
    }

    private var ctaTitle: String {
        switch selected {
        case .yearly:
            return "Subscribe yearly · \(pro.priceText(for: .yearly))"
        case .yearlySpecial:
            return "Claim offer · \(pro.priceText(for: .yearlySpecial))"
        case .lifetime:
            return "Unlock lifetime · \(pro.priceText(for: .lifetime))"
        case .monthly:
            return "Subscribe monthly · \(pro.priceText(for: .monthly))"
        }
    }

    private var restoreRow: some View {
        Button("Restore purchases") {
            Task { await pro.restore() }
        }
        .font(InpensoTheme.label(13, weight: .semibold))
        .foregroundStyle(InpensoTheme.tide)
        .frame(maxWidth: .infinity)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            Text("Included")
                .font(InpensoTheme.sectionLabel())
                .foregroundStyle(InpensoTheme.ink)

            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.element.title) { index, feature in
                    HStack(alignment: .top, spacing: InpensoTheme.Space.sm) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(InpensoTheme.ink)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(InpensoTheme.body(14, weight: .semibold))
                                .foregroundStyle(InpensoTheme.ink)
                            Text(feature.detail)
                                .font(InpensoTheme.label(12))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, InpensoTheme.Space.sm)

                    if index < features.count - 1 {
                        Divider().overlay(InpensoTheme.hairline)
                    }
                }
            }
            .padding(.horizontal, InpensoTheme.Space.md)
            .inpensoPanelBackground()
        }
    }

    private var legalFooter: some View {
        Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage in Settings → Apple ID.")
            .font(InpensoTheme.label(11))
            .foregroundStyle(InpensoTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Special 60% offer

struct SpecialOfferPaywallView: View {
    @ObservedObject var pro: ProEntitlementManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            InpensoTheme.ink.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                        pro.showSpecialOffer = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(InpensoTheme.ink)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                    .fill(InpensoTheme.mist)
                            )
                    }
                }
                .padding(.horizontal, InpensoTheme.Space.lg)
                .padding(.top, InpensoTheme.Space.md)

                VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                    Text("Yearly plan · 60% off")
                        .font(InpensoTheme.label(12, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)
                        .textCase(.uppercase)

                    Text("Limited-time yearly price")
                        .font(InpensoTheme.brandFont(24, weight: .bold))
                        .foregroundStyle(InpensoTheme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, InpensoTheme.Space.lg)
                .padding(.bottom, InpensoTheme.Space.md)

                VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("$29.99")
                            .font(InpensoTheme.body(18, weight: .medium))
                            .foregroundStyle(InpensoTheme.muted)
                            .strikethrough()
                        Text(pro.priceText(for: .yearlySpecial))
                            .font(InpensoTheme.displayAmount(36))
                            .foregroundStyle(InpensoTheme.ink)
                        Text("/ year")
                            .font(InpensoTheme.label(14, weight: .medium))
                            .foregroundStyle(InpensoTheme.muted)
                    }

                    Text("\(ProPlan.yearlySpecial.weeklyEquivalent ?? "$0.23")/week. All Pro features, no ads.")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.slate)

                    VStack(alignment: .leading, spacing: 8) {
                        offerBullet("Unlimited OCR, sync, and widgets")
                        offerBullet("Goals, accounts, and merchant rules")
                        offerBullet("CSV, OFX, and PDF exports")
                    }

                    Button {
                        Task {
                            _ = await pro.purchase(.yearlySpecial)
                        }
                    } label: {
                        HStack {
                            if pro.purchaseInFlight { ProgressView().tint(.white) }
                            Text("Subscribe at 60% off")
                        }
                    }
                    .buttonStyle(InpensoPrimaryButtonStyle(enabled: !pro.purchaseInFlight))
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
                .padding(InpensoTheme.Space.lg)
                .background(InpensoTheme.foam)
            }
            .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
            .inpensoScreenPadding()
            .padding(.vertical, InpensoTheme.Space.xl)
        }
    }

    private func offerBullet(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(InpensoTheme.surplus)
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
            Text(compact ? "Pro" : "Upgrade")
                .font(InpensoTheme.label(compact ? 11 : 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 10 : 14)
                .padding(.vertical, compact ? 6 : 8)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        .fill(InpensoTheme.ink)
                )
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(InpensoTheme.ink)
                    .frame(width: 32, height: 32)
                    .background(
                        InpensoTheme.mist,
                        in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(message)
                        .font(InpensoTheme.body(13, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Upgrade to Pro")
                        .font(InpensoTheme.label(12, weight: .semibold))
                        .foregroundStyle(InpensoTheme.tide)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(InpensoTheme.Space.md)
            .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
        }
        .buttonStyle(.plain)
    }
}
