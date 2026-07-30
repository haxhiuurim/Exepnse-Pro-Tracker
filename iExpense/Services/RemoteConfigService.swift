//
//  RemoteConfigService.swift
//  iExpense
//
//  Polls backend remote config + heartbeat; drives maintenance / force-update / premium grants.
//

import Foundation
import Combine
import UIKit

struct RemoteAnnouncement: Equatable {
    var active: Bool
    var title: String
    var message: String
}

struct RemoteFeatures: Equatable {
    var trips: Bool
    var sync: Bool
    var registration: Bool
    var receiptScan: Bool
}

struct RemoteAppConfig: Equatable {
    var maintenanceMode: Bool
    var maintenanceMessage: String
    var forceUpdate: Bool
    var minIOSVersion: String
    var minAppVersion: String
    var appStoreURL: String
    var supportEmail: String
    var announcement: RemoteAnnouncement
    var features: RemoteFeatures

    static let fallback = RemoteAppConfig(
        maintenanceMode: false,
        maintenanceMessage: "Expense is temporarily unavailable.",
        forceUpdate: false,
        minIOSVersion: "17.0",
        minAppVersion: "1.0.0",
        appStoreURL: "https://apps.apple.com",
        supportEmail: "support@usolution.cloud",
        announcement: RemoteAnnouncement(active: false, title: "", message: ""),
        features: RemoteFeatures(trips: true, sync: true, registration: true, receiptScan: true)
    )
}

@MainActor
final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()

    @Published private(set) var config: RemoteAppConfig = .fallback
    @Published private(set) var serverPremium = false
    @Published private(set) var serverPremiumUntil: String?
    @Published private(set) var lastHeartbeatAt: Date?
    @Published private(set) var isAccountBanned = false
    @Published private(set) var bannedMessage =
        "This account has been suspended. Contact support if you believe this is a mistake."
    @Published var showAnnouncement = false

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let cache = "remoteAppConfigCache"
        static let announcementSeen = "remoteAnnouncementFingerprint"
        static let accountBanned = "remoteAccountBanned"
        static let bannedMessage = "remoteBannedMessage"
    }

    private init() {
        if let data = defaults.data(forKey: Keys.cache),
           let cached = try? JSONDecoder().decode(CodableConfig.self, from: data) {
            config = cached.asModel
        }
        isAccountBanned = defaults.bool(forKey: Keys.accountBanned)
        if let stored = defaults.string(forKey: Keys.bannedMessage), !stored.isEmpty {
            bannedMessage = stored
        }
    }

    var needsForceUpdate: Bool {
        if config.forceUpdate { return true }
        return isVersion(DeviceIdentity.appVersion, lessThan: config.minAppVersion)
            || isVersion(DeviceIdentity.iosVersion, lessThan: config.minIOSVersion)
    }

    var blocksApp: Bool {
        isAccountBanned || config.maintenanceMode || needsForceUpdate
    }

    func applyAccountBan(message: String? = nil) {
        let text = (message?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "This account has been suspended. Contact support if you believe this is a mistake."
        isAccountBanned = true
        bannedMessage = text
        defaults.set(true, forKey: Keys.accountBanned)
        defaults.set(text, forKey: Keys.bannedMessage)
        serverPremium = false
        serverPremiumUntil = nil
        ProEntitlementManager.shared.applyServerPremium(false)
        SharedTripAPI.shared.revokeSessionLocally()
    }

    func clearAccountBan() {
        isAccountBanned = false
        defaults.set(false, forKey: Keys.accountBanned)
        defaults.removeObject(forKey: Keys.bannedMessage)
        bannedMessage = "This account has been suspended. Contact support if you believe this is a mistake."
    }

    func refresh(markDataChange: Bool = false) async {
        var mePremium: Bool?
        var meUntil: String?

        // Prefer /me when signed in — entitlement source of truth.
        if SharedTripAPI.shared.isLoggedIn {
            do {
                let me = try await SharedTripAPI.shared.fetchMe()
                mePremium = me.premium
                meUntil = me.premiumUntil
                serverPremium = me.premium
                serverPremiumUntil = me.premiumUntil
            } catch let SharedTripAPIError.accountBanned(message) {
                applyAccountBan(message: message)
                return
            } catch {
                // Fall through to heartbeat.
            }
        }

        do {
            let payload = try await SharedTripAPI.shared.heartbeat(markDataChange: markDataChange)
            if let cfg = payload.config {
                config = cfg
                cache(cfg)
                maybeShowAnnouncement(cfg.announcement)
            }
            lastHeartbeatAt = Date()

            if payload.banned {
                applyAccountBan(message: payload.bannedMessage)
                return
            }

            // Successful authed heartbeat means the account is not banned.
            if SharedTripAPI.shared.isLoggedIn || AuthSession.shared.isLoggedIn {
                // Prefer explicit /me result; otherwise trust heartbeat when it reports premium.
                let granted = mePremium ?? payload.premium
                // If /me said true, never let a false heartbeat clear it in the same refresh.
                let finalGrant = (mePremium == true) ? true : granted
                serverPremium = finalGrant
                serverPremiumUntil = meUntil ?? payload.premiumUntil
                ProEntitlementManager.shared.applyServerPremium(finalGrant)
            } else {
                serverPremium = false
                serverPremiumUntil = nil
                ProEntitlementManager.shared.applyServerPremium(false)
            }
        } catch let SharedTripAPIError.accountBanned(message) {
            applyAccountBan(message: message)
        } catch {
            // Soft-fail offline — keep last known /me result if we got one.
            if let mePremium {
                ProEntitlementManager.shared.applyServerPremium(mePremium)
            }
        }
    }

    private func maybeShowAnnouncement(_ ann: RemoteAnnouncement) {
        guard ann.active, !ann.message.isEmpty else { return }
        let fingerprint = ann.title + "|" + ann.message
        if defaults.string(forKey: Keys.announcementSeen) == fingerprint { return }
        defaults.set(fingerprint, forKey: Keys.announcementSeen)
        showAnnouncement = true
    }

    private func cache(_ config: RemoteAppConfig) {
        if let data = try? JSONEncoder().encode(CodableConfig(config)) {
            defaults.set(data, forKey: Keys.cache)
        }
    }

    private func isVersion(_ current: String, lessThan minimum: String) -> Bool {
        let a = current.split(separator: ".").compactMap { Int($0) }
        let b = minimum.split(separator: ".").compactMap { Int($0) }
        let n = max(a.count, b.count)
        for i in 0..<n {
            let lhs = i < a.count ? a[i] : 0
            let rhs = i < b.count ? b[i] : 0
            if lhs < rhs { return true }
            if lhs > rhs { return false }
        }
        return false
    }
}

private struct CodableConfig: Codable {
    var maintenanceMode: Bool
    var maintenanceMessage: String
    var forceUpdate: Bool
    var minIOSVersion: String
    var minAppVersion: String
    var appStoreURL: String
    var supportEmail: String
    var announcementActive: Bool
    var announcementTitle: String
    var announcementMessage: String
    var trips: Bool
    var sync: Bool
    var registration: Bool
    var receiptScan: Bool

    init(_ c: RemoteAppConfig) {
        maintenanceMode = c.maintenanceMode
        maintenanceMessage = c.maintenanceMessage
        forceUpdate = c.forceUpdate
        minIOSVersion = c.minIOSVersion
        minAppVersion = c.minAppVersion
        appStoreURL = c.appStoreURL
        supportEmail = c.supportEmail
        announcementActive = c.announcement.active
        announcementTitle = c.announcement.title
        announcementMessage = c.announcement.message
        trips = c.features.trips
        sync = c.features.sync
        registration = c.features.registration
        receiptScan = c.features.receiptScan
    }

    var asModel: RemoteAppConfig {
        RemoteAppConfig(
            maintenanceMode: maintenanceMode,
            maintenanceMessage: maintenanceMessage,
            forceUpdate: forceUpdate,
            minIOSVersion: minIOSVersion,
            minAppVersion: minAppVersion,
            appStoreURL: appStoreURL,
            supportEmail: supportEmail,
            announcement: RemoteAnnouncement(
                active: announcementActive,
                title: announcementTitle,
                message: announcementMessage
            ),
            features: RemoteFeatures(
                trips: trips,
                sync: sync,
                registration: registration,
                receiptScan: receiptScan
            )
        )
    }
}
