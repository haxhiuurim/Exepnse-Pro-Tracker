//
//  ProEntitlementManager.swift
//  iExpense
//
//  StoreKit 2 subscription entitlement + free-tier limits.
//

import Foundation
import StoreKit
import SwiftUI
import Combine

enum ProProductID {
    static let monthly = "com.premiumsolutions.expenses.pro.monthly"
    static let yearly = "com.premiumsolutions.expenses.pro.yearly"
    static let yearlySpecial = "com.premiumsolutions.expenses.pro.yearly.special"
    static let lifetime = "com.premiumsolutions.expenses.pro.lifetime"

    static let all: [String] = [monthly, yearly, yearlySpecial, lifetime]
}

enum ProPlan: String, Identifiable, CaseIterable {
    case monthly
    case yearly
    case yearlySpecial
    case lifetime

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .monthly: return ProProductID.monthly
        case .yearly: return ProProductID.yearly
        case .yearlySpecial: return ProProductID.yearlySpecial
        case .lifetime: return ProProductID.lifetime
        }
    }

    /// Marketing display prices (fallback when StoreKit products aren't loaded).
    var displayPrice: String {
        switch self {
        case .monthly: return "$2.99"
        case .yearly: return "$14.99"
        case .yearlySpecial: return "$11.99"
        case .lifetime: return "$59.99"
        }
    }

    var strikethroughPrice: String? {
        switch self {
        case .monthly, .lifetime: return nil
        case .yearly: return "$29.99"
        case .yearlySpecial: return "$29.99"
        }
    }

    var discountPercent: Int? {
        switch self {
        case .monthly, .lifetime: return nil
        case .yearly: return 50
        case .yearlySpecial: return 60
        }
    }

    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly, .yearlySpecial: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly: return "Flexible · cancel anytime"
        case .yearly: return "Best value · 50% off"
        case .yearlySpecial: return "Limited offer · 60% off"
        case .lifetime: return "Pay once · keep Pro forever"
        }
    }

    /// Weekly equivalent for yearly intro price.
    var weeklyEquivalent: String? {
        switch self {
        case .monthly, .lifetime: return nil
        case .yearly: return "$0.29"
        case .yearlySpecial: return "$0.23"
        }
    }
}

enum FreeTierLimits {
    static let receiptScansPerMonth = 5
    static let categoryBudgets = 2
    static let recurringItems = 3
    static let uniqueTags = 5
    static let freeMerchantCustomRules = 0
}

@MainActor
final class ProEntitlementManager: ObservableObject {
    static let shared = ProEntitlementManager()

    @Published private(set) var isPro: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInFlight = false
    @Published var lastError: String?
    @Published var showPaywall = false
    @Published var showSpecialOffer = false
    @Published var selectedPaywallPlan: ProPlan = .yearly

    /// StoreKit entitlement (purchase / restore).
    private var storePro = false
    /// Admin-granted premium from the backend.
    private var serverPro = false

    private var updatesTask: Task<Void, Never>?

    private enum Keys {
        static let debugPro = "debugForceProUnlocked"
        static let specialOfferSeenAt = "specialOfferLastShownAt"
        static let specialOfferDismissCount = "specialOfferDismissCount"
        static let receiptScanMonth = "receiptScanMonthKey"
        static let receiptScanCount = "receiptScanCount"
        static let serverPro = "serverGrantedPro"
    }

    init() {
        serverPro = UserDefaults.standard.bool(forKey: Keys.serverPro)
        #if DEBUG
        if UserDefaults.standard.bool(forKey: Keys.debugPro) {
            isPro = true
        }
        #endif
        recomputePro()
        updatesTask = listenForTransactions()
        Task { await refresh() }
    }

    func applyServerPremium(_ granted: Bool) {
        serverPro = granted
        UserDefaults.standard.set(granted, forKey: Keys.serverPro)
        recomputePro()
        if granted {
            showPaywall = false
            showSpecialOffer = false
        }
    }

    /// True when Pro comes from admin grant (not StoreKit).
    var isServerGrantedPro: Bool { serverPro }

    private func recomputePro() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: Keys.debugPro) {
            isPro = true
            return
        }
        #endif
        isPro = storePro || serverPro
    }

    // MARK: - Entitlement

    func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: Keys.debugPro) {
            isPro = true
            return
        }
        #endif

        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               ProProductID.all.contains(transaction.productID) {
                entitled = true
                break
            }
        }
        storePro = entitled
        recomputePro()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Set(ProProductID.all))
                .sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    func product(for plan: ProPlan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    func priceText(for plan: ProPlan) -> String {
        if let product = product(for: plan) {
            return product.displayPrice
        }
        return plan.displayPrice
    }

    // MARK: - Purchase

    func purchase(_ plan: ProPlan) async -> Bool {
        purchaseInFlight = true
        lastError = nil
        defer { purchaseInFlight = false }

        // Prefer StoreKit product when available
        if let product = product(for: plan) {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    let transaction = try checkVerified(verification)
                    await transaction.finish()
                    await refreshEntitlements()
                    HapticFeedback.success()
                    showPaywall = false
                    showSpecialOffer = false
                    return isPro
                case .userCancelled:
                    return false
                case .pending:
                    lastError = "Purchase is pending approval."
                    return false
                @unknown default:
                    return false
                }
            } catch {
                lastError = error.localizedDescription
                // Fall through to simulator unlock in DEBUG
            }
        }

        #if DEBUG
        // Simulator / no App Store products — unlock for UI testing
        UserDefaults.standard.set(true, forKey: Keys.debugPro)
        isPro = true
        HapticFeedback.success()
        showPaywall = false
        showSpecialOffer = false
        return true
        #else
        if lastError == nil {
            lastError = "Subscriptions aren’t available yet. Please try again later."
        }
        HapticFeedback.error()
        return false
        #endif
    }

    func restore() async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro {
                lastError = "No active \(AppBrand.proName) subscription found."
            } else {
                showPaywall = false
                showSpecialOffer = false
                HapticFeedback.success()
            }
        } catch {
            lastError = error.localizedDescription
            HapticFeedback.error()
        }
    }

    #if DEBUG
    func debugTogglePro() {
        let enabling = !isPro
        UserDefaults.standard.set(enabling, forKey: Keys.debugPro)
        if !enabling {
            // Re-evaluate StoreKit + server grant after clearing debug override.
            recomputePro()
        } else {
            isPro = true
        }
    }
    #endif

    // MARK: - Special offer (limit-triggered, not random)

    /// Prefer calling when the user hits a free-tier ceiling.
    func presentSpecialOfferIfEligible(force: Bool = false) {
        guard !isPro else { return }
        guard !showPaywall, !showSpecialOffer else { return }

        let defaults = UserDefaults.standard
        let now = Date()
        if !force,
           let last = defaults.object(forKey: Keys.specialOfferSeenAt) as? Date,
           now.timeIntervalSince(last) < 60 * 60 * 36 {
            return
        }

        defaults.set(now, forKey: Keys.specialOfferSeenAt)
        selectedPaywallPlan = .yearlySpecial
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.showSpecialOffer = true
        }
    }

    /// Kept for call-site compatibility — no longer random; only cool-down aware no-op.
    func maybePresentSpecialOffer() {
        // Random interrupt removed in favor of limit-hit offers.
    }

    func openPaywall(plan: ProPlan = .yearly) {
        // Never prompt if Pro is already unlocked (StoreKit or admin grant).
        guard !isPro else {
            showPaywall = false
            showSpecialOffer = false
            return
        }
        selectedPaywallPlan = plan == .yearlySpecial ? .yearlySpecial : plan
        showPaywall = true
    }

    func notifyLimitHit() {
        presentSpecialOfferIfEligible()
    }

    // MARK: - Free tier usage

    var receiptScansUsedThisMonth: Int {
        rotateReceiptCounterIfNeeded()
        return UserDefaults.standard.integer(forKey: Keys.receiptScanCount)
    }

    var receiptScansRemaining: Int {
        if isPro { return .max }
        return max(0, FreeTierLimits.receiptScansPerMonth - receiptScansUsedThisMonth)
    }

    var canScanReceipt: Bool {
        isPro || receiptScansRemaining > 0
    }

    func recordReceiptScan() {
        guard !isPro else { return }
        rotateReceiptCounterIfNeeded()
        let count = UserDefaults.standard.integer(forKey: Keys.receiptScanCount) + 1
        UserDefaults.standard.set(count, forKey: Keys.receiptScanCount)
        objectWillChange.send()
        if count >= FreeTierLimits.receiptScansPerMonth {
            notifyLimitHit()
        }
    }

    func canAddCategoryBudget(currentCount: Int) -> Bool {
        isPro || currentCount < FreeTierLimits.categoryBudgets
    }

    func canAddRecurring(currentCount: Int) -> Bool {
        isPro || currentCount < FreeTierLimits.recurringItems
    }

    func canUseTag(existingUniqueTags: Set<String>, newTags: [String]) -> Bool {
        if isPro { return true }
        var union = existingUniqueTags
        for tag in newTags { union.insert(tag) }
        return union.count <= FreeTierLimits.uniqueTags
    }

    /// Full Insights (trends / deep cards) — Pro or 14-day preview.
    var canUseFullInsights: Bool {
        isPro || OnboardingStore.shared.insightsPreviewActive
    }

    var canUseInsightsOverview: Bool { true }

    private func rotateReceiptCounterIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let key = formatter.string(from: Date())
        let stored = UserDefaults.standard.string(forKey: Keys.receiptScanMonth)
        if stored != key {
            UserDefaults.standard.set(key, forKey: Keys.receiptScanMonth)
            UserDefaults.standard.set(0, forKey: Keys.receiptScanCount)
        }
    }

    // MARK: - Helpers

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
