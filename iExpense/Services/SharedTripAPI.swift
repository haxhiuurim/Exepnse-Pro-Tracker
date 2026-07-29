//
//  SharedTripAPI.swift
//  iExpense
//
//  Client for the PHP shared-trip backend (invite codes + balances).
//

import Foundation

enum SharedTripAPIError: LocalizedError {
    case notConfigured
    case server(String)
    case decoding
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Shared trips aren’t configured. Check your connection and try again."
        case .server(let message): return message
        case .decoding: return "Could not read the server response."
        case .unauthorized: return "Session expired. Re-registering…"
        }
    }
}

final class SharedTripAPI {
    static let shared = SharedTripAPI()

    /// Production shared-trips backend.
    static let defaultBaseURL = "https://expense.usolution.cloud"

    private let defaults = UserDefaults.standard
    private let baseURLKey = "sharedTripsBaseURL"
    private let tokenKey = "sharedTripsAPIToken"
    private let userIDKey = "sharedTripsUserID"
    private let displayNameKey = "sharedTripsDisplayName"

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

    // MARK: - Auth

    func ensureRegistered(displayName: String) async throws {
        if token != nil, userID != nil { return }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw SharedTripAPIError.server("Enter a display name first.")
        }
        self.displayName = name
        let data = try await postJSON(
            path: "/api/auth/register",
            body: ["display_name": name],
            authed: false
        )
        guard
            let userID = data["user_id"] as? Int,
            let apiToken = data["api_token"] as? String
        else { throw SharedTripAPIError.decoding }
        self.userID = userID
        self.token = apiToken
    }

    // MARK: - Trips

    func fetchTrips() async throws -> [SharedTripSummary] {
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

    func joinTrip(inviteCode: String) async throws -> SharedTripSummary {
        let data = try await postJSON(
            path: "/api/trips/join",
            body: ["invite_code": inviteCode.uppercased()],
            authed: true
        )
        let tripDict = (data["trip"] as? [String: Any]) ?? data
        guard let trip = SharedTripSummary(dict: tripDict) else { throw SharedTripAPIError.decoding }
        return trip
    }

    func tripDetail(id: Int) async throws -> SharedTripDetail {
        let data = try await getJSON(path: "/api/trips/\(id)")
        guard let detail = SharedTripDetail(dict: data) else { throw SharedTripAPIError.decoding }
        return detail
    }

    func addExpense(
        tripID: Int,
        title: String,
        amount: Double,
        paidByMemberID: Int
    ) async throws {
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
        _ = try await request(
            path: "/api/trips/\(tripID)/expenses/\(expenseID)",
            method: "DELETE",
            body: nil,
            authed: true
        )
    }

    func leaveTrip(id: Int) async throws {
        _ = try await postJSON(path: "/api/trips/\(id)/leave", body: [:], authed: true)
    }

    func deleteTrip(id: Int) async throws {
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
        // Trim trailing slash
        if base.absoluteString.hasSuffix("/") {
            base = base.deletingLastPathComponent()
            // deletingLastPathComponent on http://host:8080/ removes port path oddly — rebuild
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
            throw SharedTripAPIError.unauthorized
        }
        if !ok {
            throw SharedTripAPIError.server(envelope["error"] as? String ?? "Request failed (\(http.statusCode))")
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
        // Prefer explicit ownership from API when present on the envelope.
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
