//
//  TripShortcutsStore.swift
//  iExpense
//
//  Home-screen shortcuts to specific shared trips + App Group cache for widgets.
//

import Foundation
import Combine
import WidgetKit

struct TripShortcut: Identifiable, Codable, Hashable {
    let id: Int
    var name: String
    var currency: String
    var inviteCode: String
}

struct TripWidgetSnapshot: Codable, Hashable, Identifiable {
    let id: Int
    var name: String
    var currency: String
    var mySpent: Double
    var totalSpent: Double
    var netBalance: Double // positive = owed to you, negative = you owe

    var owedToYou: Double { max(0, netBalance) }
    var youOwe: Double { max(0, -netBalance) }
}

@MainActor
final class TripShortcutsStore: ObservableObject {
    static let shared = TripShortcutsStore()

    @Published private(set) var shortcuts: [TripShortcut] = []

    private let defaults = UserDefaults.standard
    private let key = "tripHomeShortcuts"
    private let widgetCacheKey = "tripWidgetSnapshots"

    private init() {
        load()
    }

    func isPinned(_ tripID: Int) -> Bool {
        shortcuts.contains(where: { $0.id == tripID })
    }

    func toggle(trip: SharedTripSummary) {
        if let idx = shortcuts.firstIndex(where: { $0.id == trip.id }) {
            shortcuts.remove(at: idx)
        } else {
            shortcuts.append(TripShortcut(
                id: trip.id,
                name: trip.name,
                currency: trip.currency,
                inviteCode: trip.inviteCode
            ))
        }
        persist()
        CloudSyncService.shared.schedulePush()
    }

    func updateCache(from detail: SharedTripDetail) {
        var snapshots = loadWidgetSnapshots()
        let me = detail.members.first(where: { $0.id == detail.myMemberID })
        let snap = TripWidgetSnapshot(
            id: detail.trip.id,
            name: detail.trip.name,
            currency: detail.trip.currency,
            mySpent: me?.paid ?? 0,
            totalSpent: detail.trip.totalSpent > 0
                ? detail.trip.totalSpent
                : detail.expenses.reduce(0) { $0 + $1.amount },
            netBalance: me?.net ?? 0
        )
        if let idx = snapshots.firstIndex(where: { $0.id == snap.id }) {
            snapshots[idx] = snap
        } else {
            snapshots.append(snap)
        }
        // Keep pinned trips + recently viewed
        saveWidgetSnapshots(snapshots)
        WidgetCenter.shared.reloadTimelines(ofKind: "TripSummaryWidget")
    }

    func encodedPayload() -> Any {
        (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(shortcuts))) ?? []
    }

    func applyServerPayload(_ raw: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: raw),
              let decoded = try? JSONDecoder().decode([TripShortcut].self, from: data) else { return }
        shortcuts = decoded
        persist(notifySync: false)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TripShortcut].self, from: data) else {
            shortcuts = []
            return
        }
        shortcuts = decoded
    }

    private func persist(notifySync: Bool = true) {
        if let data = try? JSONEncoder().encode(shortcuts) {
            defaults.set(data, forKey: key)
            UserDefaults(suiteName: StorageService.appGroupID)?.set(data, forKey: key)
        }
        if notifySync {
            // no-op flag for callers that already schedule push
        }
    }

    nonisolated static func loadWidgetSnapshotsFromAppGroup() -> [TripWidgetSnapshot] {
        guard let data = UserDefaults(suiteName: StorageService.appGroupID)?.data(forKey: "tripWidgetSnapshots"),
              let decoded = try? JSONDecoder().decode([TripWidgetSnapshot].self, from: data) else {
            return []
        }
        return decoded
    }

    private func loadWidgetSnapshots() -> [TripWidgetSnapshot] {
        Self.loadWidgetSnapshotsFromAppGroup()
    }

    private func saveWidgetSnapshots(_ snapshots: [TripWidgetSnapshot]) {
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults(suiteName: StorageService.appGroupID)?.set(data, forKey: widgetCacheKey)
            defaults.set(data, forKey: widgetCacheKey)
        }
    }
}
