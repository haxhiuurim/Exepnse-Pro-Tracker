//
//  BiometricLockService.swift
//  iExpense
//
//  Optional Face ID / Touch ID gate when opening the app.
//

import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class BiometricLockService: ObservableObject {
    static let shared = BiometricLockService()

    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if isEnabled {
                isUnlocked = false
            } else {
                isUnlocked = true
            }
        }
    }

    @Published var isUnlocked: Bool = true
    @Published var lastErrorMessage: String?

    private enum Keys {
        static let enabled = "biometricLockEnabled"
    }

    var biometryLabel: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Face ID / Touch ID"
        }
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Device Passcode"
        }
    }

    var biometrySymbol: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.shield"
        }
    }

    var canUseBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            || context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        isUnlocked = !isEnabled
    }

    func lockIfNeeded() {
        guard isEnabled else {
            isUnlocked = true
            return
        }
        isUnlocked = false
    }

    func authenticate(force: Bool = false) async -> Bool {
        guard isEnabled || force else {
            isUnlocked = true
            return true
        }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        let policy: LAPolicy
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            policy = .deviceOwnerAuthentication
        } else {
            lastErrorMessage = error?.localizedDescription ?? "Biometrics unavailable on this device."
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                policy,
                localizedReason: "Unlock Inpenso to view your spending."
            )
            isUnlocked = success
            if success { lastErrorMessage = nil }
            return success
        } catch {
            lastErrorMessage = error.localizedDescription
            isUnlocked = false
            return false
        }
    }

    func enableAfterAuth() async -> Bool {
        let ok = await authenticate(force: true)
        if ok {
            // Avoid didSet side-effects fighting unlock state
            UserDefaults.standard.set(true, forKey: Keys.enabled)
            isEnabled = true
            isUnlocked = true
        }
        return ok
    }
}
