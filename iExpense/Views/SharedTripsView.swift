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
    @State private var showConnection = false

    var body: some View {
        ZStack {
            AtmosphereBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                    tripsBrandHeader
                    headerCopy
                    primaryActions
                    tripsList
                    if let error = model.errorMessage {
                        Text(error)
                            .font(InpensoTheme.body(14))
                            .foregroundStyle(InpensoTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, InpensoTheme.Space.screen)
                .padding(.top, InpensoTheme.Space.md)
                .padding(.bottom, InpensoTheme.Space.bottomClearance)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showConnection = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(
                            InpensoTheme.mist,
                            in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        )
                }
                .accessibilityLabel("Trip connection settings")
            }
        }
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .sheet(isPresented: $showConnection) {
            NavigationStack {
                TripConnectionSheet(model: model)
            }
            .presentationDetents([.medium])
        }
        .alert("Create trip", isPresented: $model.showCreate) {
            TextField("Trip name", text: $model.newTripName)
            Button("Create") {
                Task { await model.createTrip(currency: settingsViewModel.selectedCurrency) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll get an invite code to share with friends.")
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

    private var tripsBrandHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Trips")
                .font(InpensoTheme.brandFont(28, weight: .heavy))
                .foregroundStyle(InpensoTheme.ink)
            Text("Split spendings with friends")
                .font(InpensoTheme.label(13))
                .foregroundStyle(InpensoTheme.muted)
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Create a trip, share the invite code, and track who paid what.")
                .font(InpensoTheme.body(14))
                .foregroundStyle(InpensoTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryActions: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            Button {
                model.showCreate = true
            } label: {
                Label("Create", systemImage: "plus")
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

    private var tripsList: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            InpensoSectionHeader(title: "Your trips")

            if model.isLoading && model.trips.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, InpensoTheme.Space.xl)
            } else if model.trips.isEmpty {
                VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                    Text("No trips yet")
                        .font(InpensoTheme.body(16, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("Create a trip for a weekend away, or join one with an invite code.")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(InpensoTheme.Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .inpensoPanelBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.trips.enumerated()), id: \.element.id) { index, trip in
                        NavigationLink {
                            SharedTripDetailView(tripID: trip.id)
                        } label: {
                            HStack(spacing: InpensoTheme.Space.sm) {
                                Image(systemName: "suitcase.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(InpensoTheme.tide)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        InpensoTheme.tide.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(trip.name)
                                        .font(InpensoTheme.body(16, weight: .semibold))
                                        .foregroundStyle(InpensoTheme.ink)
                                    Text("\(trip.inviteCode) · \(trip.memberCount) people · \(trip.currency)")
                                        .font(InpensoTheme.label(12))
                                        .foregroundStyle(InpensoTheme.muted)
                                }

                                Spacer(minLength: 4)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(InpensoTheme.muted)
                            }
                            .padding(.horizontal, InpensoTheme.Space.md)
                            .padding(.vertical, InpensoTheme.Space.sm + 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < model.trips.count - 1 {
                            Divider()
                                .overlay(InpensoTheme.hairline)
                                .padding(.leading, 68)
                        }
                    }
                }
                .inpensoPanelBackground()
            }
        }
    }
}

private struct TripConnectionSheet: View {
    @ObservedObject var model: SharedTripsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("Your display name", text: $model.displayName)
                TextField("API base URL", text: $model.baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            } header: {
                Text("Connection")
            } footer: {
                Text("Host the PHP backend from /backend, then paste its public URL here.")
            }

            Section {
                Button("Save & refresh") {
                    Task {
                        await model.refresh()
                        dismiss()
                    }
                }
                .font(InpensoTheme.body(16, weight: .semibold))
                .foregroundStyle(InpensoTheme.ink)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AtmosphereBackground())
        .navigationTitle("Connection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
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
            errorMessage = "Invite code \(trip.inviteCode) copied — share it with friends."
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
                    Section("Invite code") {
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

                    Section("Shared expenses") {
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
