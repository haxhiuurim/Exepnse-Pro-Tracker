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
    @Published var showAnnouncement = false

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let cache = "remoteAppConfigCache"
        static let announcementSeen = "remoteAnnouncementFingerprint"
    }

    private init() {
        if let data = defaults.data(forKey: Keys.cache),
           let cached = try? JSONDecoder().decode(CodableConfig.self, from: data) {
            config = cached.asModel
        }
    }

    var needsForceUpdate: Bool {
        if config.forceUpdate { return true }
        return isVersion(DeviceIdentity.appVersion, lessThan: config.minAppVersion)
            || isVersion(DeviceIdentity.iosVersion, lessThan: config.minIOSVersion)
    }

    var blocksApp: Bool {
        config.maintenanceMode || needsForceUpdate
    }

    func refresh(markDataChange: Bool = false) async {
        do {
            let payload = try await SharedTripAPI.shared.heartbeat(markDataChange: markDataChange)
            if let cfg = payload.config {
                config = cfg
                cache(cfg)
                maybeShowAnnouncement(cfg.announcement)
            }
            serverPremium = payload.premium
            serverPremiumUntil = payload.premiumUntil
            lastHeartbeatAt = Date()
            ProEntitlementManager.shared.applyServerPremium(payload.premium)
        } catch {
            // Soft-fail offline.
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
