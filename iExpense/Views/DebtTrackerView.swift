//
//  DebtTrackerView.swift
//  iExpense
//
//  Local debt / EMI payoff plans (no bank sync).
//

import SwiftUI

struct DebtTrackerView: View {
    @EnvironmentObject private var pro: ProEntitlementManager
    @EnvironmentObject private var settings: SettingsViewModel
    @ObservedObject private var store = PremiumDataStore.shared
    @State private var editing: DebtLoan?
    @State private var showEditor = false
    @State private var paymentDebt: DebtLoan?

    private var currency: String { settings.selectedCurrency }

    private var totalRemaining: Double {
        store.debts.reduce(0) { $0 + $1.remaining }
    }

    private var monthlyEMI: Double {
        store.debts.filter { $0.remaining > 0 }.reduce(0) { $0 + $1.emiAmount }
    }

    var body: some View {
        ZStack {
            AtmosphereBackground(intensity: 0.5)
            List {
                if !pro.isPro {
                    Section {
                        ProGateBanner(message: "Debt & EMI payoff plans unlock with Pro.") {
                            pro.openPaywall()
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                if !store.debts.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Still owed")
                                .font(InpensoTheme.label(12))
                                .foregroundStyle(InpensoTheme.muted)
                            Text(totalRemaining, format: .currency(code: currency))
                                .font(InpensoTheme.displayAmount(28))
                                .foregroundStyle(InpensoTheme.expenseTint)
                            Text("\(monthlyEMI.formatted(.currency(code: currency)))/mo in EMIs")
                                .font(InpensoTheme.label(12))
                                .foregroundStyle(InpensoTheme.slate)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    if store.debts.isEmpty {
                        Text(pro.isPro
                             ? "Add a loan or EMI to track payoff without linking a bank."
                             : "Upgrade to track loans and EMIs privately on device.")
                            .font(InpensoTheme.body(14))
                            .foregroundStyle(InpensoTheme.muted)
                    } else {
                        ForEach(store.debts) { debt in
                            Button {
                                guard pro.isPro else { pro.openPaywall(); return }
                                editing = debt
                                showEditor = true
                            } label: {
                                debtRow(debt)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                if pro.isPro, debt.remaining > 0 {
                                    Button("Pay EMI") {
                                        paymentDebt = debt
                                    }
                                    .tint(InpensoTheme.tide)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            guard pro.isPro else { return }
                            indexSet.map { store.debts[$0] }.forEach(store.deleteDebt)
                        }
                    }
                } header: {
                    Text("Loans & EMIs")
                } footer: {
                    Text("Payments stay on your device. Swipe a loan to log one EMI.")
                }
            }
            .premiumListChromePublic()
        }
        .navigationTitle("Debt & EMI")
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard pro.isPro else { pro.openPaywall(); return }
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus").foregroundStyle(InpensoTheme.ink)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            DebtEditorSheet(existing: editing) { store.upsertDebt($0) }
                .environmentObject(settings)
        }
        .alert("Record EMI payment?", isPresented: Binding(
            get: { paymentDebt != nil },
            set: { if !$0 { paymentDebt = nil } }
        )) {
            Button("Cancel", role: .cancel) { paymentDebt = nil }
            Button("Record") {
                if let debt = paymentDebt {
                    store.recordDebtPayment(debt, amount: debt.emiAmount)
                }
                paymentDebt = nil
            }
        } message: {
            if let debt = paymentDebt {
                Text("Subtract \(debt.emiAmount.formatted(.currency(code: currency))) from \(debt.name) and advance the due date one month.")
            }
        }
    }

    private func debtRow(_ debt: DebtLoan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(debt.accent)
                Text(debt.name)
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Spacer()
                Text(debt.remaining, format: .currency(code: currency))
                    .font(InpensoTheme.displayAmount(14))
                    .foregroundStyle(InpensoTheme.ink)
            }
            ProgressView(value: debt.progress)
                .tint(debt.accent)
            HStack {
                Text("EMI \(debt.emiAmount.formatted(.currency(code: currency)))")
                Spacer()
                if debt.remaining > 0 {
                    Text("~ \(debt.monthsRemainingEstimate) mo · due \(debt.nextDueDate.formatted(.dateTime.month(.abbreviated).day()))")
                } else {
                    Text("Paid off")
                        .foregroundStyle(InpensoTheme.incomeTint)
                }
            }
            .font(InpensoTheme.label(11))
            .foregroundStyle(InpensoTheme.muted)
        }
        .padding(.vertical, 4)
    }
}

private struct DebtEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel
    let existing: DebtLoan?
    let onSave: (DebtLoan) -> Void

    @State private var name = ""
    @State private var principal = ""
    @State private var remaining = ""
    @State private var emi = ""
    @State private var rate = ""
    @State private var nextDue = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Loan") {
                    TextField("Name", text: $name)
                    TextField("Original principal", text: $principal)
                        .keyboardType(.decimalPad)
                    TextField("Remaining balance", text: $remaining)
                        .keyboardType(.decimalPad)
                    TextField("EMI amount", text: $emi)
                        .keyboardType(.decimalPad)
                    TextField("Interest % / year (optional)", text: $rate)
                        .keyboardType(.decimalPad)
                    DatePicker("Next due", selection: $nextDue, displayedComponents: .date)
                }
                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(existing == nil ? "Add debt" : "Edit debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                guard let existing else { return }
                name = existing.name
                principal = String(format: "%.2f", existing.principal)
                remaining = String(format: "%.2f", existing.remaining)
                emi = String(format: "%.2f", existing.emiAmount)
                rate = existing.annualInterestPercent > 0 ? String(format: "%.2f", existing.annualInterestPercent) : ""
                nextDue = existing.nextDueDate
                notes = existing.notes ?? ""
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (Double(principal.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
            && (Double(emi.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private func save() {
        let p = Double(principal.replacingOccurrences(of: ",", with: ".")) ?? 0
        let r = Double(remaining.replacingOccurrences(of: ",", with: ".")) ?? p
        let e = Double(emi.replacingOccurrences(of: ",", with: ".")) ?? 0
        let interest = Double(rate.replacingOccurrences(of: ",", with: ".")) ?? 0
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(DebtLoan(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            principal: p,
            remaining: r,
            emiAmount: e,
            annualInterestPercent: interest,
            nextDueDate: nextDue,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            accentHex: existing?.accentHex ?? "#C45C26"
        ))
        dismiss()
    }
}

/// Public wrapper — PremiumFeatureViews keeps chrome private.
extension View {
    func premiumListChromePublic() -> some View {
        self
            .scrollContentBackground(.hidden)
            .listRowBackground(InpensoTheme.panelFill)
            .listRowSeparatorTint(InpensoTheme.hairline)
            .listSectionSpacing(InpensoTheme.Space.section)
    }
}
