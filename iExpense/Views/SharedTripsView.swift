//
//  SharedTripsView.swift
//  iExpense
//
//  Trips tab — Obsidian + Jade banking language (matches Home / Activity / More).
//

import SwiftUI

struct SharedTripsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @StateObject private var model = SharedTripsViewModel()
    @FocusState private var nameFieldFocused: Bool

    @State private var nameDraft = SharedTripAPI.shared.displayName
    @State private var requiresNameSetup =
        SharedTripAPI.shared.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    @State private var pendingTripID: Int?

    private var totalSharedSpend: Double {
        model.trips.reduce(0) { $0 + $1.totalSpent }
    }

    private var totalMembers: Int {
        model.trips.reduce(0) { $0 + $1.memberCount }
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            if requiresNameSetup {
                displayNameGate
            } else {
                tripsContent
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard !requiresNameSetup else { return }
            await model.refresh()
        }
        .refreshable {
            guard !requiresNameSetup else { return }
            await model.refresh()
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
            Text("You'll get an invite code to share. Friends split fairly — no bank linking.")
        }
        .navigationDestination(isPresented: Binding(
            get: { pendingTripID != nil },
            set: { if !$0 { pendingTripID = nil } }
        )) {
            if let id = pendingTripID {
                SharedTripDetailView(tripID: id, autoShareInvite: true)
            }
        }
        .alert("Join trip", isPresented: $model.showJoin) {
            TextField("Invite code", text: $model.joinCode)
                .textInputAutocapitalization(.characters)
            Button("Join") { Task { await model.joinTrip() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the code your friend shared.")
        }
    }

    // MARK: - Display name gate

    private var displayNameGate: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trips")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)

                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR NAME")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.55))

                    Text("How friends see you")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("This name appears on shared balances. Trips is where you split weekends, roommates, and dinners — no bank linking.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("Your name", text: $nameDraft)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(InpensoTheme.ink)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white)
                        )
                        .focused($nameFieldFocused)
                        .submitLabel(.continue)
                        .onSubmit { continueWithName() }

                    Button(action: continueWithName) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(InpensoTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(.white))
                    }
                    .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
                .padding(20)
                .background(BankingHeroBackground())
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, InpensoTheme.Space.bottomClearance)
        }
        .onAppear { nameFieldFocused = true }
    }

    private func continueWithName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        nameDraft = trimmed
        model.displayName = trimmed
        SharedTripAPI.shared.displayName = trimmed
        requiresNameSetup = false
        Task { await model.refresh() }
    }

    private func editDisplayName() {
        nameDraft = model.displayName
        requiresNameSetup = true
    }

    // MARK: - Main content

    private var tripsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                heroCard
                tripsList
                if let error = model.errorMessage {
                    errorBanner(error)
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
                Text("Shared spend with friends")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer()

            Button { editDisplayName() } label: {
                Text(model.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(InpensoTheme.panelFill)
                            .shadow(color: InpensoTheme.ink.opacity(0.05), radius: 8, y: 2)
                    )
            }
            .accessibilityLabel("Edit display name")

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
                .contentTransition(.numericText())

            HStack(spacing: 10) {
                metaBadge(
                    title: "Trips",
                    value: "\(model.trips.count)"
                )
                metaBadge(
                    title: "People",
                    value: "\(totalMembers)"
                )
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

    private func metaBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(InpensoTheme.seafoam)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - List

    private var tripsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your trips")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(InpensoTheme.ink)

            if model.isLoading && model.trips.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 28)
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                        .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 10, y: 3)
                )
            } else if model.trips.isEmpty {
                tripsEmptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(model.trips) { trip in
                        NavigationLink {
                            SharedTripDetailView(tripID: trip.id)
                        } label: {
                            tripCard(trip)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private var tripsEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "suitcase.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
                .frame(width: 40, height: 40)
                .background(
                    InpensoTheme.tide.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            Text("No trips yet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(InpensoTheme.ink)

            Text("Create a trip for weekends, roommates, or dinners — invite with a code and settle fairly.")
                .font(.system(size: 14))
                .foregroundStyle(InpensoTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button { model.showCreate = true } label: {
                    Text("Create trip")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [InpensoTheme.tide, Color(inpensoHex: "#0B7A58")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                }
                Button { model.showJoin = true } label: {
                    Text("Join")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().stroke(InpensoTheme.hairline, lineWidth: 1.5)
                        )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .shadow(color: InpensoTheme.ink.opacity(0.05), radius: 12, y: 4)
        )
    }

    private func tripCard(_ trip: SharedTripSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "suitcase.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
                .frame(width: 40, height: 40)
                .background(
                    InpensoTheme.tide.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trip.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(InpensoTheme.ink)
                        .lineLimit(1)
                    if trip.isOwner {
                        Text("Owner")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(InpensoTheme.tide)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(InpensoTheme.tide.opacity(0.12), in: Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Label("\(trip.memberCount)", systemImage: "person.2")
                    if trip.expenseCount > 0 {
                        Text("·")
                        Text("\(trip.expenseCount) expenses")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(InpensoTheme.muted)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if trip.totalSpent > 0 {
                Text(trip.totalSpent, format: .currency(code: trip.currency))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(InpensoTheme.muted.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .shadow(color: InpensoTheme.ink.opacity(0.05), radius: 12, y: 4)
        )
        .contentShape(Rectangle())
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
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
}

// MARK: - View model

@MainActor
final class SharedTripsViewModel: ObservableObject {
    @Published var trips: [SharedTripSummary] = []
    @Published var displayName: String = SharedTripAPI.shared.displayName
    @Published var baseURL: String = SharedTripAPI.shared.baseURLString
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var showCreate = false
    @Published var showJoin = false
    @Published var newTripName = ""
    @Published var joinCode = ""
    @Published var lastCreatedInvite: String?

    func refresh() async {
        SharedTripAPI.shared.displayName = displayName
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await SharedTripAPI.shared.ensureRegistered(displayName: displayName)
            trips = try await SharedTripAPI.shared.fetchTrips()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func createTrip(currency: String) async -> Int? {
        do {
            try await SharedTripAPI.shared.ensureRegistered(displayName: displayName)
            let trip = try await SharedTripAPI.shared.createTrip(name: newTripName, currency: currency)
            newTripName = ""
            trips.insert(trip, at: 0)
            lastCreatedInvite = trip.inviteCode
            UIPasteboard.general.string = trip.inviteCode
            return trip.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func joinTrip() async {
        do {
            try await SharedTripAPI.shared.ensureRegistered(displayName: displayName)
            let trip = try await SharedTripAPI.shared.joinTrip(inviteCode: joinCode)
            joinCode = ""
            if !trips.contains(where: { $0.id == trip.id }) {
                trips.insert(trip, at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Detail

struct SharedTripDetailView: View {
    let tripID: Int
    var autoShareInvite: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var detail: SharedTripDetail?
    @State private var errorMessage: String?
    @State private var showAdd = false
    @State private var expenseTitle = ""
    @State private var expenseAmount = ""
    @State private var paidByMemberID: Int?
    @State private var sharePayload: SharePayload?
    @State private var showLeaveConfirm = false
    @State private var showDeleteConfirm = false

    private struct SharePayload: Identifiable {
        let id = UUID()
        let text: String
    }

    private var totalSpent: Double {
        detail?.expenses.reduce(0) { $0 + $1.amount } ?? detail?.trip.totalSpent ?? 0
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            ScrollView(showsIndicators: false) {
                if let detail {
                    VStack(alignment: .leading, spacing: 14) {
                        tripHero(detail)
                        settleUpPanel(detail)
                        balancesPanel(detail)
                        expensesPanel(detail)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 28))
                            .foregroundStyle(InpensoTheme.expenseTint)
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(InpensoTheme.ink)
                            .multilineTextAlignment(.center)
                    }
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
                        Label("Share invite", systemImage: "square.and.arrow.up")
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
            if autoShareInvite, let detail {
                presentShare(for: detail)
            }
        }
        .alert("Add shared expense", isPresented: $showAdd) {
            TextField("Title", text: $expenseTitle)
            TextField("Amount", text: $expenseAmount)
                .keyboardType(.decimalPad)
            Button("Add") { Task { await addExpense() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let detail {
                let payer = detail.members.first(where: { $0.id == (paidByMemberID ?? detail.myMemberID) })?.name
                    ?? "you"
                Text("Logged as paid by \(payer).")
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
    }

    // MARK: - Hero

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

    // MARK: - Panels

    private func settleUpPanel(_ detail: SharedTripDetail) -> some View {
        let creditors = detail.members.filter { $0.net > 0.01 }.sorted { $0.net > $1.net }
        let debtors = detail.members.filter { $0.net < -0.01 }.sorted { $0.net < $1.net }
        guard !creditors.isEmpty, !debtors.isEmpty else {
            return AnyView(EmptyView())
        }

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

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("Settle up")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)

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
                        .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 10, y: 3)
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
                    .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 10, y: 3)
            )

            Text("Positive = owed · Negative = owes")
                .font(.system(size: 12))
                .foregroundStyle(InpensoTheme.muted)
                .padding(.horizontal, 4)
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
                    if paidByMemberID == nil {
                        paidByMemberID = detail.myMemberID ?? detail.members.first?.id
                    }
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

            if detail.members.count > 1 {
                HStack {
                    Text("Paid by")
                        .font(.system(size: 13))
                        .foregroundStyle(InpensoTheme.muted)
                    Spacer()
                    Picker("Paid by", selection: Binding(
                        get: { paidByMemberID ?? detail.myMemberID ?? detail.members.first?.id ?? 0 },
                        set: { paidByMemberID = $0 }
                    )) {
                        ForEach(detail.members) { member in
                            Text(member.name).tag(member.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(InpensoTheme.tide)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                )
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
                        .shadow(color: InpensoTheme.ink.opacity(0.04), radius: 10, y: 3)
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
                Text("Paid by \(expense.paidByName)")
                    .font(.system(size: 12))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: 4)

            Text(expense.amount, format: .currency(code: currency))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(InpensoTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Data

    private func presentShare(for detail: SharedTripDetail) {
        let text = "Join my trip “\(detail.trip.name)” in \(AppBrand.name). Invite code: \(detail.trip.inviteCode)"
        UIPasteboard.general.string = detail.trip.inviteCode
        sharePayload = SharePayload(text: text)
    }

    private func load() async {
        do {
            detail = try await SharedTripAPI.shared.tripDetail(id: tripID)
            if paidByMemberID == nil {
                paidByMemberID = detail?.myMemberID ?? detail?.members.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addExpense() async {
        guard
            let detail,
            let amount = Double(expenseAmount.replacingOccurrences(of: ",", with: ".")),
            amount > 0
        else { return }
        let memberID = paidByMemberID ?? detail.myMemberID ?? detail.members.first?.id
        guard let memberID else { return }
        do {
            try await SharedTripAPI.shared.addExpense(
                tripID: tripID,
                title: expenseTitle.isEmpty ? "Expense" : expenseTitle,
                amount: amount,
                paidByMemberID: memberID
            )
            expenseTitle = ""
            expenseAmount = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteExpense(_ expenseID: Int) async {
        do {
            try await SharedTripAPI.shared.deleteExpense(tripID: tripID, expenseID: expenseID)
            await load()
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

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
