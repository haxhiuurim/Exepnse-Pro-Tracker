//
//  AuthSession.swift
//  iExpense
//
//  Backend account session (email/password). Required for Trips + cloud sync.
//

import Foundation
import Combine

@MainActor
final class AuthSession: ObservableObject {
    static let shared = AuthSession()

    @Published private(set) var isLoggedIn: Bool
    @Published private(set) var email: String
    @Published private(set) var displayName: String
    @Published private(set) var userID: Int?

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let token = "sharedTripsAPIToken"
        static let userID = "sharedTripsUserID"
        static let email = "authEmail"
        static let displayName = "sharedTripsDisplayName"
        static let guestMode = "authGuestMode"
    }

    /// User chose “continue without account” during onboarding.
    @Published var isGuest: Bool {
        didSet { defaults.set(isGuest, forKey: Keys.guestMode) }
    }

    private init() {
        let token = defaults.string(forKey: Keys.token)
        let uid = defaults.integer(forKey: Keys.userID)
        let resolvedUserID: Int? = uid == 0 ? nil : uid
        let resolvedEmail = defaults.string(forKey: Keys.email) ?? ""
        let resolvedName = defaults.string(forKey: Keys.displayName) ?? ""
        let loggedIn = token != nil && !(token?.isEmpty ?? true) && resolvedUserID != nil

        userID = resolvedUserID
        email = resolvedEmail
        displayName = resolvedName
        isLoggedIn = loggedIn
        isGuest = defaults.bool(forKey: Keys.guestMode)
    }

    var apiToken: String? {
        defaults.string(forKey: Keys.token)
    }

    func applyLogin(userID: Int, email: String, displayName: String, token: String) {
        defaults.set(token, forKey: Keys.token)
        defaults.set(userID, forKey: Keys.userID)
        defaults.set(email, forKey: Keys.email)
        defaults.set(displayName, forKey: Keys.displayName)
        self.userID = userID
        self.email = email
        self.displayName = displayName
        self.isLoggedIn = true
        self.isGuest = false
    }

    func clearSession() {
        defaults.removeObject(forKey: Keys.token)
        defaults.set(0, forKey: Keys.userID)
        // Keep email/displayName for convenience on next login form.
        userID = nil
        isLoggedIn = false
    }

    func updateDisplayName(_ name: String) {
        displayName = name
        defaults.set(name, forKey: Keys.displayName)
    }

    func continueAsGuest() {
        isGuest = true
        clearSession()
    }
}
