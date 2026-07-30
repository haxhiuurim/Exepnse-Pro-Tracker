//
//  SharedTripsView.swift
//  iExpense
//
//  Trips tab — requires backend login. Search/sort, join approval, code-only share.
//

import SwiftUI

private enum TripSort: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case name = "Name"
    case spend = "Spend"

    var id: String { rawValue }
}

struct SharedTripsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @ObservedObject private var auth = AuthSession.shared
    @StateObject private var model = SharedTripsViewModel()
    @State private var pendingTripID: Int?
    @State private var showAuth = false
    @State private var searchText = ""
    @State private var sort: TripSort = .recent
    @State private var deepLinkTripID: Int?

    private var filteredTrips: [SharedTripSummary] {
        var list = model.trips
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(q)
                    || $0.inviteCode.localizedCaseInsensitiveContains(q)
            }
        }
        switch sort {
        case .recent: break
        case .name: list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .spend: list.sort { $0.totalSpent > $1.totalSpent }
        }
        return list
    }

    private var totalSharedSpend: Double {
        model.trips.reduce(0) { $0 + $1.totalSpent }
    }

    private var totalMyNet: Double {
        model.trips.reduce(0) { $0 + $1.myNet }
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            if !auth.isLoggedIn {
                loginGate
            } else {
                tripsContent
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard auth.isLoggedIn else { return }
            await model.refresh()
        }
        .refreshable {
            guard auth.isLoggedIn else { return }
            await model.refresh()
        }
        .onChange(of: auth.isLoggedIn) { _, loggedIn in
            if loggedIn { Task { await model.refresh() } }
        }
        .alert("Create trip", isPresented: $model.showCreate) {
            TextField("Trip name", text: $model.newTripName)
            Button("Create") {
                Task {
                    if let id = await model.createTrip(currency: settingsViewModel.selectedCurrency) {
                        pendingTripID = id
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll get an invite code. Friends request to join — you approve them.")
        }
        .navigationDestination(isPresented: Binding(
            get: { pendingTripID != nil },
            set: { if !$0 { pendingTripID = nil } }
        )) {
            if let id = pendingTripID {
                SharedTripDetailView(tripID: id)
            }
        }
        .alert("Join trip", isPresented: $model.showJoin) {
            TextField("Invite code", text: $model.joinCode)
                .textInputAutocapitalization(.characters)
            Button("Request join") { Task { await model.joinTrip() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The owner must approve before you can see the trip.")
        }
        .fullScreenCover(isPresented: $showAuth) {
            AccountAuthView(onSuccess: {
                Task { await model.refresh() }
            })
        }
        .navigationDestination(isPresented: Binding(
            get: { deepLinkTripID != nil },
            set: { if !$0 { deepLinkTripID = nil } }
        )) {
            if let id = deepLinkTripID {
                SharedTripDetailView(tripID: id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSharedTrip"))) { note in
            if let id = note.userInfo?["tripID"] as? Int {
                deepLinkTripID = id
            }
        }
    }

    // MARK: - Login gate

    private var loginGate: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trips")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)

                VStack(alignment: .leading, spacing: 16) {
                    Text("ACCOUNT REQUIRED")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.55))

                    Text("Sign in to split trips")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Shared trips use your \(AppBrand.name) account. Create or sign in to make trips, share codes, and approve join requests.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    Button { showAuth = true } label: {
                        Text("Sign in or register")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(InpensoTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(.white))
                    }
                }
                .padding(20)
                .background(BankingHeroBackground())
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, InpensoTheme.Space.bottomClearance)
        }
    }

    // MARK: - Main content

    private var tripsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                heroCard
                searchAndSort
                tripsList
                if let error = model.errorMessage {
                    errorBanner(error)
                }
                if let info = model.infoMessage {
                    infoBanner(info)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, InpensoTheme.Space.bottomClearance)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trips")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                Text(auth.displayName.isEmpty ? auth.email : auth.displayName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer()

            Button { model.showCreate = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [InpensoTheme.tide, Color(inpensoHex: "#0B7A58")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .shadow(color: InpensoTheme.tide.opacity(0.35), radius: 10, y: 4)
            }
            .accessibilityLabel("Create trip")
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SHARED SPEND")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.55))

            Text(totalSharedSpend, format: .currency(code: settingsViewModel.selectedCurrency))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if abs(totalMyNet) > 0.005 {
                HStack(spacing: 6) {
                    Text(totalMyNet >= 0 ? "You are owed" : "You owe")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(signedAmountText(totalMyNet, currency: settingsViewModel.selectedCurrency))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(totalMyNet >= 0 ? InpensoTheme.seafoam : InpensoTheme.danger)
                }
            }

            HStack(spacing: 8) {
                Button { model.showCreate = true } label: {
                    Label("Create", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)

                Button { model.showJoin = true } label: {
                    Label("Join", systemImage: "person.badge.plus")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BankingHeroBackground())
    }

    private var searchAndSort: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(InpensoTheme.muted)
                TextField("Search trips", text: $searchText)
                    .textInputAutocapitalization(.never)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )

            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(TripSort.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(InpensoTheme.panelFill))
            }
        }
    }

    private var tripsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your trips")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(InpensoTheme.ink)

            if model.isLoading && model.trips.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if filteredTrips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(searchText.isEmpty ? "No trips yet" : "No matches")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                    Text(searchText.isEmpty
                         ? "Create a trip or join with a code."
                         : "Try a different search.")
                        .font(.system(size: 13))
                        .foregroundStyle(InpensoTheme.muted)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                )
            } else {
                ForEach(filteredTrips) { trip in
                    NavigationLink {
                        SharedTripDetailView(tripID: trip.id)
                    } label: {
                        tripRow(trip)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tripRow(_ trip: SharedTripSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                Text("\(trip.memberCount) people · \(trip.inviteCode)")
                    .font(.system(size: 12))
                    .foregroundStyle(InpensoTheme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(trip.totalSpent, format: .currency(code: trip.currency))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                if abs(trip.myNet) > 0.005 {
                    Text(signedAmountText(trip.myNet, currency: trip.currency))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(trip.myNet >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 10, y: 3)
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(InpensoTheme.expenseTint)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(InpensoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(InpensoTheme.expenseTint.opacity(0.08))
        )
    }

    private func infoBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(InpensoTheme.tide)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(InpensoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(InpensoTheme.tide.opacity(0.08))
        )
    }
}

// MARK: - View model

@MainActor
final class SharedTripsViewModel: ObservableObject {
    @Published var trips: [SharedTripSummary] = []
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var isLoading = false
    @Published var showCreate = false
    @Published var showJoin = false
    @Published var newTripName = ""
    @Published var joinCode = ""

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            trips = try await SharedTripAPI.shared.fetchTrips()
            errorMessage = nil
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func createTrip(currency: String) async -> Int? {
        do {
            let trip = try await SharedTripAPI.shared.createTrip(name: newTripName, currency: currency)
            newTripName = ""
            trips.insert(trip, at: 0)
            errorMessage = nil
            infoMessage = "Invite code: \(trip.inviteCode)"
            Task { await CloudSyncService.shared.pushAll() }
            return trip.id
        } catch is CancellationError {
            return nil
        } catch let urlError as URLError where urlError.code == .cancelled {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func joinTrip() async {
        do {
            let result = try await SharedTripAPI.shared.joinTrip(inviteCode: joinCode)
            joinCode = ""
            errorMessage = nil
            switch result {
            case .joined(let trip), .alreadyMember(let trip):
                if !trips.contains(where: { $0.id == trip.id }) {
                    trips.insert(trip, at: 0)
                }
                infoMessage = nil
            case .pending(let message):
                infoMessage = message
            }
            Task { await CloudSyncService.shared.pushAll() }
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Detail

struct SharedTripDetailView: View {
    let tripID: Int

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var shortcuts = TripShortcutsStore.shared
    @State private var detail: SharedTripDetail?
    @State private var errorMessage: String?
    @State private var showAdd = false
    @State private var sharePayload: SharePayload?
    @State private var showLeaveConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showSettleConfirm = false
    @State private var showAddPerson = false
    @State private var newPersonName = ""
    @State private var isSettling = false
    @State private var joinRequests: [TripJoinRequest] = []

    private struct SharePayload: Identifiable {
        let id = UUID()
        let text: String
    }

    private var totalSpent: Double {
        detail?.trip.totalSpent ?? 0
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            ScrollView(showsIndicators: false) {
                if let detail {
                    VStack(alignment: .leading, spacing: 14) {
                        tripHero(detail)
                        if detail.trip.isOwner, !joinRequests.isEmpty {
                            joinRequestsPanel
                        }
                        settleUpPanel(detail)
                        balancesPanel(detail)
                        categoryPanel(detail)
                        expensesPanel(detail)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(InpensoTheme.ink)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(InpensoTheme.panelFill)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                }
            }
        }
        .navigationTitle(detail?.trip.name ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        if let detail { presentShare(for: detail) }
                    } label: {
                        Label("Share code", systemImage: "square.and.arrow.up")
                    }
                    if let detail {
                        Button {
                            shortcuts.toggle(trip: detail.trip)
                        } label: {
                            Label(
                                shortcuts.isPinned(detail.trip.id) ? "Remove Home shortcut" : "Add to Home",
                                systemImage: shortcuts.isPinned(detail.trip.id) ? "pin.slash" : "pin"
                            )
                        }
                    }
                    Button {
                        showAddPerson = true
                    } label: {
                        Label("Add person", systemImage: "person.badge.plus")
                    }
                    Button("Leave trip", role: .destructive) {
                        showLeaveConfirm = true
                    }
                    if detail?.trip.isOwner == true {
                        Button("Delete trip", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(InpensoTheme.ink)
                }
            }
        }
        .task {
            await load()
            let defaults = UserDefaults(suiteName: StorageService.appGroupID)
            if defaults?.bool(forKey: "pendingTripShowAdd") == true {
                defaults?.set(false, forKey: "pendingTripShowAdd")
                showAdd = true
            }
        }
        .sheet(isPresented: $showAdd) {
            if let detail {
                TripQuickAddSheet(
                    tripID: tripID,
                    tripName: detail.trip.name,
                    currency: detail.trip.currency,
                    members: detail.members,
                    defaultPayerID: detail.myMemberID,
                    onSaved: { Task { await load() } }
                )
            }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(activityItems: [payload.text])
        }
        .confirmationDialog("Leave this trip?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { Task { await leaveTrip() } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this trip for everyone?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteTrip() } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Settle all debts?",
            isPresented: $showSettleConfirm,
            titleVisibility: .visible
        ) {
            Button("Settle debts", role: .destructive) { Task { await settleTrip() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let detail {
                Text(settlementSummary(detail))
            }
        }
        .alert("Add person", isPresented: $showAddPerson) {
            TextField("Name", text: $newPersonName)
            Button("Add") { Task { await addPerson() } }
            Button("Cancel", role: .cancel) { newPersonName = "" }
        } message: {
            Text("Add someone who isn't on \(AppBrand.name) yet. You can track what they owe manually.")
        }
    }

    private func tripHero(_ detail: SharedTripDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TRIP TOTAL")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.55))

            Text(totalSpent, format: .currency(code: detail.trip.currency))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if abs(detail.trip.myNet) > 0.005 {
                HStack(spacing: 6) {
                    Text(detail.trip.myNet >= 0 ? "You are owed" : "You owe")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(signedAmountText(detail.trip.myNet, currency: detail.trip.currency))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(detail.trip.myNet >= 0 ? InpensoTheme.seafoam : InpensoTheme.danger)
                }
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("INVITE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.48))
                    Text(detail.trip.inviteCode)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(InpensoTheme.seafoam)
                        .tracking(1.5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.08))
                )

                Button {
                    presentShare(for: detail)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
            }

            Text("\(detail.members.count) people · \(detail.expenses.count) expenses")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BankingHeroBackground())
    }

    private var joinRequestsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Join requests")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(InpensoTheme.ink)

            VStack(spacing: 0) {
                ForEach(Array(joinRequests.enumerated()), id: \.element.id) { index, request in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(InpensoTheme.ink)
                            if let email = request.email, !email.isEmpty {
                                Text(email)
                                    .font(.system(size: 12))
                                    .foregroundStyle(InpensoTheme.muted)
                            }
                        }
                        Spacer()
                        Button("Decline") {
                            Task { await resolveJoin(request, accept: false) }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(InpensoTheme.danger)
                        Button("Accept") {
                            Task { await resolveJoin(request, accept: true) }
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(InpensoTheme.tide)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    if index < joinRequests.count - 1 {
                        Divider().overlay(InpensoTheme.hairline).padding(.leading, 14)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )
        }
    }

    /// Greedy debtor→creditor matching so the fewest payments settle everyone up.
    private func settlementSuggestions(_ detail: SharedTripDetail) -> [(from: String, to: String, amount: Double)] {
        let creditors = detail.members.filter { $0.net > 0.01 }.sorted { $0.net > $1.net }
        let debtors = detail.members.filter { $0.net < -0.01 }.sorted { $0.net < $1.net }
        guard !creditors.isEmpty, !debtors.isEmpty else { return [] }

        var suggestions: [(from: String, to: String, amount: Double)] = []
        var debtQueue = debtors.map { (name: $0.name, owed: -$0.net) }
        var creditQueue = creditors.map { (name: $0.name, due: $0.net) }
        var di = 0, ci = 0
        while di < debtQueue.count, ci < creditQueue.count {
            let pay = min(debtQueue[di].owed, creditQueue[ci].due)
            if pay > 0.009 {
                suggestions.append((debtQueue[di].name, creditQueue[ci].name, pay))
            }
            debtQueue[di].owed -= pay
            creditQueue[ci].due -= pay
            if debtQueue[di].owed < 0.01 { di += 1 }
            if creditQueue[ci].due < 0.01 { ci += 1 }
        }
        return suggestions
    }

    private func settlementSummary(_ detail: SharedTripDetail) -> String {
        let suggestions = settlementSuggestions(detail)
        guard !suggestions.isEmpty else {
            return "Everyone is already settled up."
        }
        let lines = suggestions.map { tip in
            "\(tip.from) → \(tip.to): \(tip.amount.formatted(.currency(code: detail.trip.currency)))"
        }
        return lines.joined(separator: "\n") + "\n\nThis marks all current expenses as settled. Totals stay, balances reset to zero."
    }

    private func settleUpPanel(_ detail: SharedTripDetail) -> some View {
        let suggestions = settlementSuggestions(detail)
        guard !suggestions.isEmpty else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Settle up")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                    Spacer()
                    if detail.trip.isOwner {
                        Button {
                            showSettleConfirm = true
                        } label: {
                            if isSettling {
                                ProgressView()
                            } else {
                                Text("Settle debts")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(InpensoTheme.tide))
                            }
                        }
                        .disabled(isSettling)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, tip in
                        HStack {
                            Text("\(tip.from) → \(tip.to)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(InpensoTheme.ink)
                            Spacer()
                            Text(tip.amount, format: .currency(code: detail.trip.currency))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(InpensoTheme.tide)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        if index < suggestions.count - 1 {
                            Divider().overlay(InpensoTheme.hairline).padding(.leading, 14)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                )
            }
        )
    }

    private func balancesPanel(_ detail: SharedTripDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Balances")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(InpensoTheme.ink)

            VStack(spacing: 0) {
                ForEach(Array(detail.members.enumerated()), id: \.element.id) { index, member in
                    HStack {
                        Text(member.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(InpensoTheme.ink)
                        Spacer()
                        Text(member.net, format: .currency(code: detail.trip.currency))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(member.net >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if index < detail.members.count - 1 {
                        Divider().overlay(InpensoTheme.hairline).padding(.leading, 14)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )

            Text("Positive = owed · Negative = owes")
                .font(.system(size: 12))
                .foregroundStyle(InpensoTheme.muted)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func categoryPanel(_ detail: SharedTripDetail) -> some View {
        if !detail.categoryBreakdown.isEmpty {
            let maxAmount = detail.categoryBreakdown.map(\.amount).max() ?? 0
            VStack(alignment: .leading, spacing: 10) {
                Text("By category")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)

                VStack(spacing: 12) {
                    ForEach(Array(detail.categoryBreakdown.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(InpensoTheme.ink)
                                Spacer()
                                Text(entry.amount, format: .currency(code: detail.trip.currency))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(InpensoTheme.ink)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(InpensoTheme.mist)
                                    Capsule()
                                        .fill(InpensoTheme.tide)
                                        .frame(width: maxAmount > 0
                                            ? max(6, geo.size.width * (entry.amount / maxAmount))
                                            : 0)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                )
            }
        }
    }

    private func expensesPanel(_ detail: SharedTripDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shared expenses")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                Spacer()
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    colors: [InpensoTheme.tide, Color(inpensoHex: "#0B7A58")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                }
                .accessibilityLabel("Add shared expense")
            }

            if detail.expenses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No shared expenses yet")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("Log what someone paid for the group.")
                        .font(.system(size: 13))
                        .foregroundStyle(InpensoTheme.muted)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(detail.expenses.enumerated()), id: \.element.id) { index, expense in
                        sharedExpenseRow(expense, currency: detail.trip.currency)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    Task { await deleteExpense(expense.id) }
                                }
                            }
                        if index < detail.expenses.count - 1 {
                            Divider().overlay(InpensoTheme.hairline).padding(.leading, 66)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                )
            }
        }
    }

    private func sharedExpenseRow(_ expense: SharedTripExpense, currency: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "receipt")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
                .frame(width: 40, height: 40)
                .background(
                    InpensoTheme.tide.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(InpensoTheme.ink)
                Text(expenseSubtitle(expense))
                    .font(.system(size: 12))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount, format: .currency(code: currency))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                if expense.isSettled {
                    Text("Settled")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(InpensoTheme.tide)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func expenseSubtitle(_ expense: SharedTripExpense) -> String {
        var parts = ["Paid by \(expense.paidByName)"]
        if expense.createdByName != expense.paidByName {
            parts.append("added by \(expense.createdByName)")
        }
        if let categoryName = expense.categoryName {
            parts.append(categoryName)
        }
        return parts.joined(separator: " · ")
    }

    private func presentShare(for detail: SharedTripDetail) {
        let code = detail.trip.inviteCode
        UIPasteboard.general.string = code
        sharePayload = SharePayload(text: code)
    }

    private func load() async {
        do {
            let loaded = try await SharedTripAPI.shared.tripDetail(id: tripID)
            detail = loaded
            TripShortcutsStore.shared.updateCache(from: loaded)
            if loaded.trip.isOwner {
                joinRequests = try await SharedTripAPI.shared.fetchJoinRequests(tripID: tripID)
            } else {
                joinRequests = []
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveJoin(_ request: TripJoinRequest, accept: Bool) async {
        do {
            if accept {
                try await SharedTripAPI.shared.acceptJoinRequest(tripID: tripID, requestID: request.id)
            } else {
                try await SharedTripAPI.shared.declineJoinRequest(tripID: tripID, requestID: request.id)
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteExpense(_ expenseID: Int) async {
        do {
            try await SharedTripAPI.shared.deleteExpense(tripID: tripID, expenseID: expenseID)
            await load()
            try? await SharedTripAPI.shared.heartbeat(markDataChange: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func settleTrip() async {
        isSettling = true
        defer { isSettling = false }
        do {
            let updated = try await SharedTripAPI.shared.settleTrip(tripID: tripID)
            detail = updated
            TripShortcutsStore.shared.updateCache(from: updated)
            errorMessage = nil
            HapticFeedback.success()
            try? await SharedTripAPI.shared.heartbeat(markDataChange: true)
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
        }
    }

    private func addPerson() async {
        let name = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
        newPersonName = ""
        guard !name.isEmpty else { return }
        do {
            let updated = try await SharedTripAPI.shared.addManualMember(tripID: tripID, displayName: name)
            detail = updated
            TripShortcutsStore.shared.updateCache(from: updated)
            errorMessage = nil
            try? await SharedTripAPI.shared.heartbeat(markDataChange: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func leaveTrip() async {
        do {
            try await SharedTripAPI.shared.leaveTrip(id: tripID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTrip() async {
        do {
            try await SharedTripAPI.shared.deleteTrip(id: tripID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Formats a net balance with an explicit +/− sign, e.g. "+$12.50" or "−$4.00".
private func signedAmountText(_ value: Double, currency: String) -> String {
    let formatted = abs(value).formatted(.currency(code: currency))
    return value >= 0 ? "+\(formatted)" : "−\(formatted)"
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
