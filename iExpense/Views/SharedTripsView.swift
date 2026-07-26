//
//  SharedTripsView.swift
//  iExpense
//
//  Shared trip ledgers via invite code (PHP backend).
//

import SwiftUI

struct SharedTripsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @StateObject private var model = SharedTripsViewModel()

    var body: some View {
        ZStack {
            AtmosphereBackground()

            List {
                Section {
                    TextField("Your display name", text: $model.displayName)
                    TextField("API base URL", text: $model.baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Text("Example: https://api.yourdomain.com")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Host the PHP backend from /backend, then paste its public URL here.")
                }

                Section {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Refresh trips", systemImage: "arrow.clockwise")
                    }

                    Button {
                        model.showCreate = true
                    } label: {
                        Label("Create trip", systemImage: "plus")
                    }

                    Button {
                        model.showJoin = true
                    } label: {
                        Label("Join with invite code", systemImage: "person.badge.plus")
                    }
                }

                Section("Your trips") {
                    if model.trips.isEmpty {
                        Text(model.isLoading ? "Loading…" : "No trips yet. Create one or join with a code.")
                            .font(InpensoTheme.body(14))
                            .foregroundStyle(InpensoTheme.muted)
                    } else {
                        ForEach(model.trips) { trip in
                            NavigationLink {
                                SharedTripDetailView(tripID: trip.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trip.name)
                                        .font(InpensoTheme.body(16, weight: .semibold))
                                        .foregroundStyle(InpensoTheme.ink)
                                    Text("Code \(trip.inviteCode) · \(trip.memberCount) people · \(trip.currency)")
                                        .font(InpensoTheme.label(12))
                                        .foregroundStyle(InpensoTheme.muted)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                if let error = model.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(InpensoTheme.danger)
                            .font(InpensoTheme.body(14))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(InpensoTheme.panelFill)
            .listRowSeparatorTint(InpensoTheme.hairline)
            .listSectionSpacing(InpensoTheme.Space.section)
        }
        .navigationTitle("Shared trips")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await model.refresh() }
        .alert("Create trip", isPresented: $model.showCreate) {
            TextField("Trip name", text: $model.newTripName)
            Button("Create") { Task { await model.createTrip(currency: settingsViewModel.selectedCurrency) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Friends join with the invite code you get after creating.")
        }
        .alert("Join trip", isPresented: $model.showJoin) {
            TextField("Invite code", text: $model.joinCode)
                .textInputAutocapitalization(.characters)
            Button("Join") { Task { await model.joinTrip() } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

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

    func refresh() async {
        SharedTripAPI.shared.baseURLString = baseURL
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

    func createTrip(currency: String) async {
        SharedTripAPI.shared.baseURLString = baseURL
        do {
            try await SharedTripAPI.shared.ensureRegistered(displayName: displayName)
            let trip = try await SharedTripAPI.shared.createTrip(name: newTripName, currency: currency)
            newTripName = ""
            trips.insert(trip, at: 0)
            UIPasteboard.general.string = trip.inviteCode
            errorMessage = "Created. Invite code \(trip.inviteCode) copied."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinTrip() async {
        SharedTripAPI.shared.baseURLString = baseURL
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

struct SharedTripDetailView: View {
    let tripID: Int
    @State private var detail: SharedTripDetail?
    @State private var errorMessage: String?
    @State private var showAdd = false
    @State private var expenseTitle = ""
    @State private var expenseAmount = ""

    var body: some View {
        ZStack {
            AtmosphereBackground()
            List {
                if let detail {
                    Section("Invite") {
                        HStack {
                            Text(detail.trip.inviteCode)
                                .font(InpensoTheme.displayAmount(22))
                                .foregroundStyle(InpensoTheme.ink)
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = detail.trip.inviteCode
                            }
                            .font(InpensoTheme.label(14, weight: .semibold))
                            .foregroundStyle(InpensoTheme.tide)
                        }
                    }

                    Section("Balances") {
                        ForEach(detail.members) { member in
                            HStack {
                                Text(member.name)
                                    .font(InpensoTheme.body(15))
                                Spacer()
                                Text(member.net, format: .currency(code: detail.trip.currency))
                                    .foregroundStyle(member.net >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint)
                                    .font(InpensoTheme.displayAmount(16))
                            }
                        }
                        Text("Positive = others owe them. Negative = they owe.")
                            .font(InpensoTheme.label(12))
                            .foregroundStyle(InpensoTheme.muted)
                    }

                    Section("Expenses") {
                        if detail.expenses.isEmpty {
                            Text("No shared expenses yet.")
                                .font(InpensoTheme.body(14))
                                .foregroundStyle(InpensoTheme.muted)
                        } else {
                            ForEach(detail.expenses) { expense in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(expense.title)
                                            .font(InpensoTheme.body(15, weight: .medium))
                                        Spacer()
                                        Text(expense.amount, format: .currency(code: detail.trip.currency))
                                            .font(InpensoTheme.displayAmount(15))
                                    }
                                    Text("Paid by \(expense.paidByName)")
                                        .font(InpensoTheme.label(12))
                                        .foregroundStyle(InpensoTheme.muted)
                                }
                            }
                        }
                    }
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(InpensoTheme.danger)
                } else {
                    ProgressView()
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(InpensoTheme.panelFill)
            .listRowSeparatorTint(InpensoTheme.hairline)
            .listSectionSpacing(InpensoTheme.Space.section)
        }
        .navigationTitle(detail?.trip.name ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(InpensoTheme.ink)
                }
                .disabled(detail == nil)
            }
        }
        .task { await load() }
        .alert("Add shared expense", isPresented: $showAdd) {
            TextField("Title", text: $expenseTitle)
            TextField("Amount", text: $expenseAmount)
                .keyboardType(.decimalPad)
            Button("Add") { Task { await addExpense() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func load() async {
        do {
            detail = try await SharedTripAPI.shared.tripDetail(id: tripID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addExpense() async {
        guard
            let detail,
            let amount = Double(expenseAmount.replacingOccurrences(of: ",", with: ".")),
            amount > 0,
            let memberID = detail.myMemberID ?? detail.members.first?.id
        else { return }
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
}
