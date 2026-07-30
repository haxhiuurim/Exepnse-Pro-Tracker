//
//  ICloudSyncService.swift
//  iExpense
//
//  Deprecated — personal ledger sync now uses CloudSyncService + backend auth.
//  Kept as an empty stub so any stray references compile.
//

import Foundation

final class ICloudSyncService {
    static let shared = ICloudSyncService()

    private init() {}

    @MainActor
    func pushAll() {}

    func pullIfAvailable() {}
}

extension Notification.Name {
    static let inpensoICloudDidPull = Notification.Name("inpensoICloudDidPull")
}
