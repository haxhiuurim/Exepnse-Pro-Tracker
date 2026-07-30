//
//  DeviceIdentity.swift
//  iExpense
//
//  Persistent install UUID for guest + signed-in telemetry.
//

import Foundation
import UIKit

enum DeviceIdentity {
    private static let key = "expenseDeviceUUID"

    static var uuid: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        UserDefaults.standard.set(created, forKey: key)
        return created
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    static var iosVersion: String {
        UIDevice.current.systemVersion
    }

    static var model: String {
        UIDevice.current.model
    }

    static var locale: String {
        Locale.current.identifier
    }

    static var timezone: String {
        TimeZone.current.identifier
    }
}
