//
//  SharedTripsView.swift
//  iExpense
//
//  Primary Trips tab — split spendings with friends via invite code.
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

    private let screenInset = InpensoTheme.Space.screen

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
            VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trips")
                        .font(InpensoTheme.brandFont(28, weight: .heavy))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("Set how friends see you")
                        .font(InpensoTheme.label(13))
                        .foregroundStyle(InpensoTheme.muted)
                }

                VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                    Text("Your name for friends")
                        .font(InpensoTheme.brandFont(22, weight: .bold))
                        .foregroundStyle(InpensoTheme.ink)

                    Text("This is how you appear on shared balances. Trips is \(AppBrand.name)’s place to split group spend — weekends, roommates, dinners.")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("Your name", text: $nameDraft)
                        .font(InpensoTheme.body(17, weight: .medium))
                        .padding(InpensoTheme.Space.md)
                        .background(InpensoTheme.mist, in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous))
                        .focused($nameFieldFocused)
                        .submitLabel(.continue)
                        .onSubmit { continueWithName() }

                    Button(action: continueWithName) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.tide))
                    .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(InpensoTheme.Space.lg)
                .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
            }
            .padding(.horizontal, screenInset)
            .padding(.top, InpensoTheme.Space.sm)
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
            VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                tripsBrandHeader
                primaryActions
                tripsList
                if let error = model.errorMessage {
                    errorBanner(error)
                }
            }
            .padding(.horizontal, screenInset)
            .padding(.top, InpensoTheme.Space.sm)
            .padding(.bottom, InpensoTheme.Space.bottomClearance)
        }
    }

    // MARK: - Header

    private var tripsBrandHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trips")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                Text("Shared spend with friends")
                    .font(.system(size: 13))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Text(model.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.7)))
                    .lineLimit(1)

                Button {
                    editDisplayName()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.7)))
                }
            }
        }
    }

    // MARK: - Actions

    private var primaryActions: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            Button {
                model.showCreate = true
            } label: {
                Label("Create trip", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.tide))

            Button {
                model.showJoin = true
            } label: {
                Label("Join", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoSecondaryButtonStyle())
        }
    }

    // MARK: - List

    private var tripsList: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Your trips")

            if model.isLoading && model.trips.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, InpensoTheme.Space.xl)
                    Spacer()
                }
                .inpensoPanelBackground()
            } else if model.trips.isEmpty {
                tripsEmptyState
            } else {
                VStack(spacing: InpensoTheme.Space.sm) {
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
    }

    private var tripsEmptyState: some View {
        VStack(spacing: InpensoTheme.Space.md) {
            Image(systemName: "suitcase")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(InpensoTheme.tide.opacity(0.6))
                .frame(width: 72, height: 72)
                .background(
                    InpensoTheme.tide.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                )

            VStack(spacing: InpensoTheme.Space.xs) {
                Text("No trips yet")
                    .font(InpensoTheme.brandFont(20, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)

                Text("Create a trip for weekends, roommates, or dinners — invite with a code and settle fairly. No bank linking.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: InpensoTheme.Space.sm) {
                Button {
                    model.showCreate = true
                } label: {
                    Text("Create trip")
                        .font(InpensoTheme.label(14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                .fill(InpensoTheme.tide)
                        )
                }

                Button {
                    model.showJoin = true
                } label: {
                    Text("Join with code")
                        .font(InpensoTheme.label(14, weight: .bold))
                        .foregroundStyle(InpensoTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                .stroke(InpensoTheme.hairline, lineWidth: 1.5)
                        )
                }
            }
            .padding(.top, InpensoTheme.Space.xs)
        }
        .padding(InpensoTheme.Space.xl)
        .frame(maxWidth: .infinity)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
    }

    private func tripCard(_ trip: SharedTripSummary) -> some View {
        HStack(spacing: InpensoTheme.Space.md) {
            Image(systemName: "suitcase.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
                .frame(width: 48, height: 48)
                .background(
                    InpensoTheme.tide.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trip.name)
                        .font(InpensoTheme.body(16, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                    if trip.isOwner {
                        Text("Owner")
                            .font(InpensoTheme.label(10, weight: .bold))
                            .foregroundStyle(InpensoTheme.tide)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(InpensoTheme.tide.opacity(0.12), in: Capsule())
                    }
                }

                HStack(spacing: InpensoTheme.Space.xs) {
                    Label("\(trip.memberCount)", systemImage: "person.2")
                    if trip.expenseCount > 0 {
                        Text("·")
                        Text("\(trip.expenseCount) expenses")
                    }
                    if trip.totalSpent > 0 {
                        Text("·")
                        Text(trip.totalSpent, format: .currency(code: trip.currency))
                    }
                }
                .font(InpensoTheme.label(12))
                .foregroundStyle(InpensoTheme.muted)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(InpensoTheme.muted.opacity(0.6))
        }
        .padding(InpensoTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
        .contentShape(RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(InpensoTheme.expenseTint)
            Text(message)
                .font(InpensoTheme.body(14))
                .foregroundStyle(InpensoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(InpensoTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                .fill(InpensoTheme.expenseTint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .stroke(InpensoTheme.expenseTint.opacity(0.2), lineWidth: 1)
                )
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

    private let screenInset = InpensoTheme.Space.screen

    private struct SharePayload: Identifiable {
        let id = UUID()
        let text: String
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            ScrollView(showsIndicators: false) {
                if let detail {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                        inviteCodePanel(detail)
                        settleUpPanel(detail)
                        balancesPanel(detail)
                        expensesPanel(detail)
                    }
                    .padding(.horizontal, screenInset)
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, InpensoTheme.Space.xxl)
                } else if let errorMessage {
                    VStack(spacing: InpensoTheme.Space.md) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundStyle(InpensoTheme.expenseTint)
                        Text(errorMessage)
                            .font(InpensoTheme.body(14))
                            .foregroundStyle(InpensoTheme.ink)
                            .multilineTextAlignment(.center)
                    }
                    .padding(InpensoTheme.Space.xl)
                    .frame(maxWidth: .infinity)
                    .inpensoPanelBackground()
                    .padding(.horizontal, screenInset)
                    .padding(.top, InpensoTheme.Space.xxl)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, InpensoTheme.Space.xxl)
                }
            }
        }
        .navigationTitle(detail?.trip.name ?? "Trip")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        if let detail {
                            presentShare(for: detail)
                        }
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
            if let detail, detail.members.count > 1 {
                // Picker in alert is limited — default to selected member; list below in sheet would be better.
            }
            Button("Add") { Task { await addExpense() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let detail {
                let payer = detail.members.first(where: { $0.id == (paidByMemberID ?? detail.myMemberID) })?.name
                    ?? "you"
                Text("Logged as paid by \(payer). Change payer below before adding if needed.")
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

    // MARK: - Panels

    private func inviteCodePanel(_ detail: SharedTripDetail) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text("Invite friends")
                .font(InpensoTheme.sectionLabel())
                .foregroundStyle(InpensoTheme.muted)

            HStack(alignment: .center) {
                Text(detail.trip.inviteCode)
                    .font(InpensoTheme.displayAmount(28))
                    .foregroundStyle(InpensoTheme.ink)
                    .tracking(2)

                Spacer()

                Button {
                    presentShare(for: detail)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(InpensoTheme.label(14, weight: .bold))
                        .foregroundStyle(InpensoTheme.tide)
                        .padding(.horizontal, InpensoTheme.Space.md)
                        .padding(.vertical, InpensoTheme.Space.sm)
                        .background(
                            InpensoTheme.tide.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        )
                }
            }

            Text("Share this code so friends can join and log shared spend in \(AppBrand.name).")
                .font(InpensoTheme.body(13))
                .foregroundStyle(InpensoTheme.muted)
        }
        .padding(InpensoTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
    }

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
            VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                InpensoSectionHeader(title: "Settle up")
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, tip in
                        HStack {
                            Text("\(tip.from) → \(tip.to)")
                                .font(InpensoTheme.body(14, weight: .medium))
                                .foregroundStyle(InpensoTheme.ink)
                            Spacer()
                            Text(tip.amount, format: .currency(code: detail.trip.currency))
                                .font(InpensoTheme.displayAmount(14))
                                .foregroundStyle(InpensoTheme.tide)
                        }
                        .padding(.vertical, InpensoTheme.Space.row)
                        if index < suggestions.count - 1 {
                            Divider().overlay(InpensoTheme.hairline)
                        }
                    }
                }
                .padding(.horizontal, InpensoTheme.Space.md)
                .padding(.vertical, InpensoTheme.Space.xs)
                .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
            }
        )
    }

    private func balancesPanel(_ detail: SharedTripDetail) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Balances")

            VStack(spacing: 0) {
                ForEach(Array(detail.members.enumerated()), id: \.element.id) { index, member in
                    HStack {
                        Text(member.name)
                            .font(InpensoTheme.body(15, weight: .medium))
                            .foregroundStyle(InpensoTheme.ink)
                        Spacer()
                        Text(member.net, format: .currency(code: detail.trip.currency))
                            .font(InpensoTheme.displayAmount(16))
                            .foregroundStyle(member.net >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint)
                    }
                    .padding(.vertical, InpensoTheme.Space.row)

                    if index < detail.members.count - 1 {
                        Divider().overlay(InpensoTheme.hairline)
                    }
                }
            }
            .padding(.horizontal, InpensoTheme.Space.md)
            .padding(.vertical, InpensoTheme.Space.xs)
            .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)

            Text("Positive = others owe them · Negative = they owe.")
                .font(InpensoTheme.label(12))
                .foregroundStyle(InpensoTheme.muted)
        }
    }

    private func expensesPanel(_ detail: SharedTripDetail) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Shared expenses")

            if detail.members.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Paid by")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                    Picker("Paid by", selection: Binding(
                        get: { paidByMemberID ?? detail.myMemberID ?? detail.members.first?.id ?? 0 },
                        set: { paidByMemberID = $0 }
                    )) {
                        ForEach(detail.members) { member in
                            Text(member.name).tag(member.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, InpensoTheme.Space.md)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
                }
            }

            if detail.expenses.isEmpty {
                VStack(spacing: InpensoTheme.Space.sm) {
                    Image(systemName: "receipt")
                        .font(.system(size: 28))
                        .foregroundStyle(InpensoTheme.muted.opacity(0.5))
                    Text("No shared expenses yet")
                        .font(InpensoTheme.body(15, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("Log what someone paid for the group.")
                        .font(InpensoTheme.body(13))
                        .foregroundStyle(InpensoTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(InpensoTheme.Space.xl)
                .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
            } else {
                VStack(spacing: InpensoTheme.Space.sm) {
                    ForEach(detail.expenses) { expense in
                        sharedExpenseRow(expense, currency: detail.trip.currency)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    Task { await deleteExpense(expense.id) }
                                }
                            }
                    }
                }
            }

            Button {
                if paidByMemberID == nil {
                    paidByMemberID = detail.myMemberID ?? detail.members.first?.id
                }
                showAdd = true
            } label: {
                Text("Add shared expense")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.tide))
        }
    }

    private func sharedExpenseRow(_ expense: SharedTripExpense, currency: String) -> some View {
        HStack(alignment: .top, spacing: InpensoTheme.Space.sm) {
            Image(systemName: "receipt")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
                .frame(width: 40, height: 40)
                .background(
                    InpensoTheme.tide.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(InpensoTheme.body(15, weight: .medium))
                    .foregroundStyle(InpensoTheme.ink)
                Text("Paid by \(expense.paidByName)")
                    .font(InpensoTheme.label(12))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: 4)

            Text(expense.amount, format: .currency(code: currency))
                .font(InpensoTheme.displayAmount(15))
                .foregroundStyle(InpensoTheme.ink)
        }
        .padding(InpensoTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
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
