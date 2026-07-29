//
//  CrashReportingService.swift
//  iExpense
//
//  Lightweight on-device crash capture for a release stability gate.
//  No third-party analytics — fingerprints stay on device.
//

import Foundation
import os

enum CrashReportingService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.premiumsolutions.expenses",
        category: "stability"
    )
    static let lastCrashKey = "stability.lastCrashFingerprint"
    static let lastCrashAtKey = "stability.lastCrashAt"
    private static let sessionStartKey = "stability.sessionStartedAt"

    static func install() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: sessionStartKey)
        NSSetUncaughtExceptionHandler(expenseUncaughtExceptionHandler)
        signal(SIGABRT, expenseCrashSignalHandler)
        signal(SIGSEGV, expenseCrashSignalHandler)
        signal(SIGBUS, expenseCrashSignalHandler)
        signal(SIGILL, expenseCrashSignalHandler)
        signal(SIGFPE, expenseCrashSignalHandler)
        logger.info("Stability gate armed")
    }

    static var lastCrashFingerprint: String? {
        UserDefaults.standard.string(forKey: lastCrashKey)
    }

    static var lastCrashDate: Date? {
        let value = UserDefaults.standard.double(forKey: lastCrashAtKey)
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    static func clearCrashRecord() {
        UserDefaults.standard.removeObject(forKey: lastCrashKey)
        UserDefaults.standard.removeObject(forKey: lastCrashAtKey)
    }

    static func logFault(_ message: String) {
        logger.fault("\(message, privacy: .public)")
    }

    /// Call before shipping: false if a crash fingerprint is still on device.
    static func passesStabilityGate(requireCleanHistory: Bool = true) -> Bool {
        if requireCleanHistory, lastCrashFingerprint != nil { return false }
        return true
    }

    static func persistCrash(_ fingerprint: String) {
        UserDefaults.standard.set(fingerprint, forKey: lastCrashKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCrashAtKey)
        UserDefaults.standard.synchronize()
    }
}

private func expenseUncaughtExceptionHandler(_ exception: NSException) {
    let fingerprint = [
        exception.name.rawValue,
        exception.reason ?? "",
        exception.callStackSymbols.prefix(8).joined(separator: "|")
    ].joined(separator: " :: ")
    CrashReportingService.persistCrash(fingerprint)
}

private func expenseCrashSignalHandler(_ signalValue: Int32) {
    let name: String
    switch signalValue {
    case SIGABRT: name = "SIGABRT"
    case SIGSEGV: name = "SIGSEGV"
    case SIGBUS: name = "SIGBUS"
    case SIGILL: name = "SIGILL"
    case SIGFPE: name = "SIGFPE"
    default: name = "SIGNAL_\(signalValue)"
    }
    CrashReportingService.persistCrash(name)
    signal(signalValue, SIG_DFL)
    raise(signalValue)
}
