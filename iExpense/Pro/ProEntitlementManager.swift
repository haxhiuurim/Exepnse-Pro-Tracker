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

    static let all: [String] = [monthly, yearly, yearlySpecial]
}

enum ProPlan: String, Identifiable, CaseIterable {
    case monthly
    case yearly
    case yearlySpecial

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .monthly: return ProProductID.monthly
        case .yearly: return ProProductID.yearly
        case .yearlySpecial: return ProProductID.yearlySpecial
        }
    }

    /// Marketing display prices (fallback when StoreKit products aren't loaded).
    var displayPrice: String {
        switch self {
        case .monthly: return "$2.99"
        case .yearly: return "$14.99"
        case .yearlySpecial: return "$11.99"
        }
    }

    var strikethroughPrice: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "$29.99"
        case .yearlySpecial: return "$29.99"
        }
    }

    var discountPercent: Int? {
        switch self {
        case .monthly: return nil
        case .yearly: return 50
        case .yearlySpecial: return 60
        }
    }

    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly, .yearlySpecial: return "Yearly"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly: return "Flexible · cancel anytime"
        case .yearly: return "Best value · 50% off"
        case .yearlySpecial: return "Limited offer · 60% off"
        }
    }

    /// Weekly equivalent for yearly intro price.
    var weeklyEquivalent: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "$0.29"
        case .yearlySpecial: return "$0.23"
        }
    }
}

enum FreeTierLimits {
    static let receiptScansPerMonth = 5
    static let categoryBudgets = 2
    static let recurringItems = 3
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

    private var updatesTask: Task<Void, Never>?

    private enum Keys {
        static let debugPro = "debugForceProUnlocked"
        static let specialOfferSeenAt = "specialOfferLastShownAt"
        static let specialOfferDismissCount = "specialOfferDismissCount"
        static let receiptScanMonth = "receiptScanMonthKey"
        static let receiptScanCount = "receiptScanCount"
    }

    init() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: Keys.debugPro) {
            isPro = true
        }
        #endif
        updatesTask = listenForTransactions()
        Task { await refresh() }
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
        isPro = entitled
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
                lastError = "No active Inpenso Pro subscription found."
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
        let next = !isPro
        UserDefaults.standard.set(next, forKey: Keys.debugPro)
        isPro = next
    }
    #endif

    // MARK: - Special offer (random)

    /// Call on home appear — randomly presents 60% off yearly if not Pro.
    func maybePresentSpecialOffer() {
        guard !isPro else { return }
        guard !showPaywall, !showSpecialOffer else { return }

        let defaults = UserDefaults.standard
        let now = Date()
        if let last = defaults.object(forKey: Keys.specialOfferSeenAt) as? Date,
           now.timeIntervalSince(last) < 60 * 60 * 36 {
            return // cool-down ~1.5 days
        }

        // ~35% chance each eligible open
        guard Int.random(in: 1...100) <= 35 else { return }

        defaults.set(now, forKey: Keys.specialOfferSeenAt)
        selectedPaywallPlan = .yearlySpecial
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.showSpecialOffer = true
        }
    }

    func openPaywall(plan: ProPlan = .yearly) {
        selectedPaywallPlan = plan
        showPaywall = true
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
    }

    func canAddCategoryBudget(currentCount: Int) -> Bool {
        isPro || currentCount < FreeTierLimits.categoryBudgets
    }

    func canAddRecurring(currentCount: Int) -> Bool {
        isPro || currentCount < FreeTierLimits.recurringItems
    }

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
