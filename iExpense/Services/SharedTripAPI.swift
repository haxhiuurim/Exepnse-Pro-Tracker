//
//  SharedTripAPI.swift
//  iExpense
//
//  Client for the Expense backend: auth, ledger sync, shared trips.
//

import Foundation

enum SharedTripAPIError: LocalizedError {
    case notConfigured
    case server(String)
    case decoding
    case unauthorized
    case loginRequired

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Shared trips aren’t configured. Check your connection and try again."
        case .server(let message): return message
        case .decoding: return "Could not read the server response."
        case .unauthorized: return "Session expired. Please sign in again."
        case .loginRequired: return "Sign in to use Trips and sync your data."
        }
    }
}

enum JoinTripResult {
    case joined(SharedTripSummary)
    case alreadyMember(SharedTripSummary)
    case pending(message: String)
}

struct TripJoinRequest: Identifiable, Hashable {
    let id: Int
    let tripID: Int
    let userID: Int
    let displayName: String
    let email: String?
    let status: String
    let createdAt: String

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? Int ?? (dict["id"] as? String).flatMap(Int.init) else { return nil }
        self.id = id
        self.tripID = dict["trip_id"] as? Int ?? 0
        self.userID = dict["user_id"] as? Int ?? 0
        self.displayName = dict["display_name"] as? String ?? "User"
        self.email = dict["email"] as? String
        self.status = dict["status"] as? String ?? "pending"
        self.createdAt = dict["created_at"] as? String ?? ""
    }
}

final class SharedTripAPI {
    static let shared = SharedTripAPI()

    static let defaultBaseURL = "https://expense.usolution.cloud"

    private let defaults = UserDefaults.standard
    private let baseURLKey = "sharedTripsBaseURL"
    private let tokenKey = "sharedTripsAPIToken"
    private let userIDKey = "sharedTripsUserID"
    private let displayNameKey = "sharedTripsDisplayName"
    private let emailKey = "authEmail"

    private init() {}

    var baseURLString: String {
        get {
            let stored = defaults.string(forKey: baseURLKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return stored.isEmpty ? Self.defaultBaseURL : stored
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(trimmed.isEmpty ? Self.defaultBaseURL : trimmed, forKey: baseURLKey)
        }
    }

    var displayName: String {
        get { defaults.string(forKey: displayNameKey) ?? "" }
        set { defaults.set(newValue, forKey: displayNameKey) }
    }

    var isConfigured: Bool {
        guard let url = URL(string: baseURLString), url.scheme != nil, !baseURLString.isEmpty else { return false }
        return true
    }

    var isLoggedIn: Bool { token != nil && userID != nil }

    private var token: String? {
        get { defaults.string(forKey: tokenKey) }
        set { defaults.set(newValue, forKey: tokenKey) }
    }

    private var userID: Int? {
        get {
            let value = defaults.integer(forKey: userIDKey)
            return value == 0 ? nil : value
        }
        set { defaults.set(newValue ?? 0, forKey: userIDKey) }
    }

    // MARK: - Sync / telemetry

    struct HeartbeatResult {
        var premium: Bool
        var premiumUntil: String?
        var config: RemoteAppConfig?
    }

    func heartbeat(markDataChange: Bool = false) async throws -> HeartbeatResult {
        var body: [String: Any] = [
            "device_uuid": DeviceIdentity.uuid,
            "app_version": DeviceIdentity.appVersion,
            "ios_version": DeviceIdentity.iosVersion,
            "device_model": DeviceIdentity.model,
            "locale": DeviceIdentity.locale,
            "timezone": DeviceIdentity.timezone
        ]
        if markDataChange {
            body["mark_data_change"] = true
        }

        let data = try await request(
            path: "/api/telemetry/heartbeat",
            method: "POST",
            body: body,
            authed: isLoggedIn
        )

        let premium = data["premium"] as? Bool ?? false
        let until = data["premium_until"] as? String
        var remote: RemoteAppConfig?
        if let cfg = data["config"] as? [String: Any] {
            remote = Self.parseRemoteConfig(cfg)
        }
        return HeartbeatResult(premium: premium, premiumUntil: until, config: remote)
    }

    func fetchPublicConfig() async throws -> RemoteAppConfig {
        let data = try await request(path: "/api/config", method: "GET", body: nil, authed: false)
        return Self.parseRemoteConfig(data)
    }

    private static func parseRemoteConfig(_ cfg: [String: Any]) -> RemoteAppConfig {
        let features = cfg["features"] as? [String: Any] ?? [:]
        let ann = cfg["announcement"] as? [String: Any] ?? [:]
        return RemoteAppConfig(
            maintenanceMode: cfg["maintenance_mode"] as? Bool ?? false,
            maintenanceMessage: cfg["maintenance_message"] as? String
                ?? RemoteAppConfig.fallback.maintenanceMessage,
            forceUpdate: cfg["force_update"] as? Bool ?? false,
            minIOSVersion: cfg["min_ios_version"] as? String ?? "17.0",
            minAppVersion: cfg["min_app_version"] as? String ?? "1.0.0",
            appStoreURL: cfg["app_store_url"] as? String ?? "https://apps.apple.com",
            supportEmail: cfg["support_email"] as? String ?? "support@usolution.cloud",
            announcement: RemoteAnnouncement(
                active: ann["active"] as? Bool ?? false,
                title: ann["title"] as? String ?? "",
                message: ann["message"] as? String ?? ""
            ),
            features: RemoteFeatures(
                trips: features["trips"] as? Bool ?? true,
                sync: features["sync"] as? Bool ?? true,
                registration: features["registration"] as? Bool ?? true,
                receiptScan: features["receipt_scan"] as? Bool ?? true
            )
        )
    }

    // MARK: - Auth

    @MainActor
    func register(email: String, password: String, displayName: String) async throws {
        let data = try await postJSON(
            path: "/api/auth/register",
            body: [
                "email": email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                "password": password,
                "display_name": displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            ],
            authed: false
        )
        try applyAuthResponse(data)
    }

    @MainActor
    func login(email: String, password: String) async throws {
        let data = try await postJSON(
            path: "/api/auth/login",
            body: [
                "email": email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                "password": password
            ],
            authed: false
        )
        try applyAuthResponse(data)
    }

    @MainActor
    func logout() async {
        if token != nil {
            _ = try? await postJSON(path: "/api/auth/logout", body: [:], authed: true)
        }
        token = nil
        userID = nil
        AuthSession.shared.clearSession()
    }

    @MainActor
    private func applyAuthResponse(_ data: [String: Any]) throws {
        guard
            let userID = data["user_id"] as? Int ?? (data["user_id"] as? String).flatMap(Int.init),
            let apiToken = data["api_token"] as? String
        else { throw SharedTripAPIError.decoding }
        let email = data["email"] as? String ?? ""
        let name = data["display_name"] as? String ?? ""
        self.userID = userID
        self.token = apiToken
        self.displayName = name
        defaults.set(email, forKey: emailKey)
        AuthSession.shared.applyLogin(userID: userID, email: email, displayName: name, token: apiToken)
    }

    /// Trips require a logged-in backend account.
    func requireLogin() throws {
        guard isLoggedIn else { throw SharedTripAPIError.loginRequired }
    }

    // MARK: - Sync

    func pullSync() async throws -> [String: Any] {
        try requireLogin()
        let data = try await getJSON(path: "/api/sync")
        return (data["documents"] as? [String: Any]) ?? [:]
    }

    func pushSync(documents: [String: Any]) async throws {
        try requireLogin()
        _ = try await request(
            path: "/api/sync",
            method: "PUT",
            body: ["documents": documents],
            authed: true
        )
    }

    // MARK: - Trips

    func fetchTrips() async throws -> [SharedTripSummary] {
        try requireLogin()
        let raw = try await requestRaw(path: "/api/trips", method: "GET", body: nil, authed: true)
        if let arr = raw as? [[String: Any]] {
            return arr.compactMap(SharedTripSummary.init(dict:))
        }
        if let dict = raw as? [String: Any], let trips = dict["trips"] as? [[String: Any]] {
            return trips.compactMap(SharedTripSummary.init(dict:))
        }
        return []
    }

    func createTrip(name: String, currency: String) async throws -> SharedTripSummary {
        try requireLogin()
        let data = try await postJSON(
            path: "/api/trips",
            body: [
                "name": name,
                "currency": currency
            ],
            authed: true
        )
        let tripDict = (data["trip"] as? [String: Any]) ?? data
        guard let trip = SharedTripSummary(dict: tripDict) else { throw SharedTripAPIError.decoding }
        return trip
    }

    func joinTrip(inviteCode: String) async throws -> JoinTripResult {
        try requireLogin()
        let data = try await postJSON(
            path: "/api/trips/join",
            body: ["invite_code": inviteCode.uppercased()],
            authed: true
        )
        let status = data["status"] as? String ?? "joined"
        let tripDict = (data["trip"] as? [String: Any]) ?? data
        let trip = SharedTripSummary(dict: tripDict)

        switch status {
        case "pending":
            return .pending(message: data["message"] as? String
                ?? "Join request sent. Waiting for the trip owner to approve.")
        case "already_member":
            guard let trip else { throw SharedTripAPIError.decoding }
            return .alreadyMember(trip)
        default:
            guard let trip else { throw SharedTripAPIError.decoding }
            return .joined(trip)
        }
    }

    func tripDetail(id: Int) async throws -> SharedTripDetail {
        try requireLogin()
        let data = try await getJSON(path: "/api/trips/\(id)")
        guard let detail = SharedTripDetail(dict: data) else { throw SharedTripAPIError.decoding }
        return detail
    }

    func fetchJoinRequests(tripID: Int) async throws -> [TripJoinRequest] {
        try requireLogin()
        let raw = try await requestRaw(
            path: "/api/trips/\(tripID)/join-requests",
            method: "GET",
            body: nil,
            authed: true
        )
        let rows = (raw as? [[String: Any]])
            ?? (raw as? [String: Any])?["requests"] as? [[String: Any]]
            ?? []
        return rows.compactMap(TripJoinRequest.init(dict:))
    }

    func acceptJoinRequest(tripID: Int, requestID: Int) async throws {
        try requireLogin()
        _ = try await postJSON(
            path: "/api/trips/\(tripID)/join-requests/\(requestID)/accept",
            body: [:],
            authed: true
        )
    }

    func declineJoinRequest(tripID: Int, requestID: Int) async throws {
        try requireLogin()
        _ = try await postJSON(
            path: "/api/trips/\(tripID)/join-requests/\(requestID)/decline",
            body: [:],
            authed: true
        )
    }

    func addExpense(
        tripID: Int,
        title: String,
        amount: Double,
        paidByMemberID: Int
    ) async throws {
        try requireLogin()
        _ = try await postJSON(
            path: "/api/trips/\(tripID)/expenses",
            body: [
                "title": title,
                "amount": amount,
                "paid_by_member_id": paidByMemberID
            ],
            authed: true
        )
    }

    func deleteExpense(tripID: Int, expenseID: Int) async throws {
        try requireLogin()
        _ = try await request(
            path: "/api/trips/\(tripID)/expenses/\(expenseID)",
            method: "DELETE",
            body: nil,
            authed: true
        )
    }

    func leaveTrip(id: Int) async throws {
        try requireLogin()
        _ = try await postJSON(path: "/api/trips/\(id)/leave", body: [:], authed: true)
    }

    func deleteTrip(id: Int) async throws {
        try requireLogin()
        _ = try await request(path: "/api/trips/\(id)", method: "DELETE", body: nil, authed: true)
    }

    // MARK: - Networking

    private func getJSON(path: String) async throws -> [String: Any] {
        try await request(path: path, method: "GET", body: nil, authed: true)
    }

    private func postJSON(path: String, body: [String: Any], authed: Bool) async throws -> [String: Any] {
        try await request(path: path, method: "POST", body: body, authed: authed)
    }

    private func request(
        path: String,
        method: String,
        body: [String: Any]?,
        authed: Bool
    ) async throws -> [String: Any] {
        let raw = try await requestRaw(path: path, method: method, body: body, authed: authed)
        guard let dict = raw as? [String: Any] else { throw SharedTripAPIError.decoding }
        return dict
    }

    private func requestRaw(
        path: String,
        method: String,
        body: [String: Any]?,
        authed: Bool
    ) async throws -> Any {
        guard isConfigured, var base = URL(string: baseURLString) else {
            throw SharedTripAPIError.notConfigured
        }
        if base.absoluteString.hasSuffix("/") {
            if let rebuilt = URL(string: baseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) {
                base = rebuilt
            }
        }
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw SharedTripAPIError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if authed {
            guard let token else { throw SharedTripAPIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SharedTripAPIError.decoding }

        let json = try JSONSerialization.jsonObject(with: data)
        guard let envelope = json as? [String: Any] else { throw SharedTripAPIError.decoding }

        let ok = envelope["ok"] as? Bool ?? false
        if http.statusCode == 401 {
            self.token = nil
            self.userID = nil
            await MainActor.run { AuthSession.shared.clearSession() }
            throw SharedTripAPIError.unauthorized
        }
        // 202 Accepted is success for pending join
        if !ok && !(200...299).contains(http.statusCode) {
            throw SharedTripAPIError.server(envelope["error"] as? String ?? "Request failed (\(http.statusCode))")
        }
        if !ok, let err = envelope["error"] as? String {
            throw SharedTripAPIError.server(err)
        }
        return envelope["data"] ?? [:]
    }
}

// MARK: - Models

struct SharedTripSummary: Identifiable, Hashable {
    let id: Int
    let name: String
    let inviteCode: String
    let currency: String
    let memberCount: Int
    let expenseCount: Int
    let totalSpent: Double
    let isOwner: Bool

    init(
        id: Int,
        name: String,
        inviteCode: String,
        currency: String,
        memberCount: Int,
        expenseCount: Int,
        totalSpent: Double,
        isOwner: Bool
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.currency = currency
        self.memberCount = memberCount
        self.expenseCount = expenseCount
        self.totalSpent = totalSpent
        self.isOwner = isOwner
    }

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? Int ?? (dict["id"] as? String).flatMap(Int.init) else { return nil }
        self.id = id
        self.name = dict["name"] as? String ?? "Trip"
        self.inviteCode = dict["invite_code"] as? String ?? ""
        self.currency = dict["currency"] as? String ?? "USD"
        self.memberCount = dict["member_count"] as? Int
            ?? (dict["members"] as? [Any])?.count
            ?? 0
        self.expenseCount = dict["expense_count"] as? Int ?? 0
        if let total = dict["total_spent"] as? Double {
            self.totalSpent = total
        } else if let total = dict["total_spent"] as? NSNumber {
            self.totalSpent = total.doubleValue
        } else if let total = dict["total_spent"] as? String {
            self.totalSpent = Double(total) ?? 0
        } else {
            self.totalSpent = 0
        }
        self.isOwner = dict["is_owner"] as? Bool ?? false
    }
}

struct SharedTripMember: Identifiable, Hashable {
    let id: Int
    let name: String
    let paid: Double
    let owed: Double
    let net: Double

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? Int ?? (dict["member_id"] as? Int) else { return nil }
        self.id = id
        self.name = dict["display_name"] as? String ?? dict["name"] as? String ?? "Member"
        self.paid = (dict["paid"] as? Double) ?? (dict["paid"] as? NSNumber)?.doubleValue ?? 0
        self.owed = (dict["owed"] as? Double) ?? (dict["owed"] as? NSNumber)?.doubleValue ?? 0
        self.net = (dict["net"] as? Double) ?? (dict["net"] as? NSNumber)?.doubleValue ?? 0
    }
}

struct SharedTripExpense: Identifiable, Hashable {
    let id: Int
    let title: String
    let amount: Double
    let paidByName: String
    let createdAt: String

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? Int else { return nil }
        self.id = id
        self.title = dict["title"] as? String ?? "Expense"
        self.amount = (dict["amount"] as? Double) ?? (dict["amount"] as? NSNumber)?.doubleValue ?? 0
        self.paidByName = dict["paid_by_name"] as? String
            ?? dict["payer_name"] as? String
            ?? "Someone"
        self.createdAt = dict["created_at"] as? String ?? ""
    }
}

struct SharedTripDetail {
    let trip: SharedTripSummary
    let members: [SharedTripMember]
    let expenses: [SharedTripExpense]
    let myMemberID: Int?

    init?(dict: [String: Any]) {
        let tripDict = (dict["trip"] as? [String: Any]) ?? dict
        guard var trip = SharedTripSummary(dict: tripDict) else { return nil }
        self.members = (dict["members"] as? [[String: Any]] ?? []).compactMap(SharedTripMember.init(dict:))
        self.expenses = (dict["expenses"] as? [[String: Any]] ?? []).compactMap(SharedTripExpense.init(dict:))
        self.myMemberID = dict["my_member_id"] as? Int
            ?? members.first(where: { $0.name == SharedTripAPI.shared.displayName })?.id
        if let isOwner = dict["is_owner"] as? Bool {
            trip = SharedTripSummary(
                id: trip.id,
                name: trip.name,
                inviteCode: trip.inviteCode,
                currency: trip.currency,
                memberCount: max(trip.memberCount, members.count),
                expenseCount: max(trip.expenseCount, expenses.count),
                totalSpent: trip.totalSpent > 0 ? trip.totalSpent : expenses.reduce(0) { $0 + $1.amount },
                isOwner: isOwner
            )
        } else if trip.memberCount == 0 || trip.expenseCount == 0 {
            trip = SharedTripSummary(
                id: trip.id,
                name: trip.name,
                inviteCode: trip.inviteCode,
                currency: trip.currency,
                memberCount: max(trip.memberCount, members.count),
                expenseCount: max(trip.expenseCount, expenses.count),
                totalSpent: trip.totalSpent > 0 ? trip.totalSpent : expenses.reduce(0) { $0 + $1.amount },
                isOwner: trip.isOwner
            )
        }
        self.trip = trip
    }
}
