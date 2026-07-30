//
//  TripQuickAddSheet.swift
//  iExpense
//
//  Quick-add style sheet for shared trip expenses (mirrors Home Quick Add).
//

import SwiftUI

struct TripQuickAddSheet: View {
    let tripID: Int
    let currency: String
    let members: [SharedTripMember]
    let defaultPayerID: Int?
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var title = ""
    @State private var paidByMemberID: Int?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    private enum Field { case amount, title }

    private var isValid: Bool {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value > 0 else { return false }
        return (paidByMemberID ?? defaultPayerID ?? members.first?.id) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.xl) {
                        Text("Shared expense")
                            .font(InpensoTheme.brandFont(24, weight: .bold))
                            .foregroundStyle(InpensoTheme.ink)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(InpensoTheme.label(13))
                                .foregroundStyle(InpensoTheme.muted)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(currencySymbol)
                                    .font(InpensoTheme.displayAmount(34))
                                    .foregroundStyle(InpensoTheme.muted)
                                TextField("0", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(InpensoTheme.displayAmount(34))
                                    .foregroundStyle(InpensoTheme.ink)
                                    .focused($focused, equals: .amount)
                            }
                            .padding(InpensoTheme.Space.md)
                            .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("What for?")
                                .font(InpensoTheme.label(13))
                                .foregroundStyle(InpensoTheme.muted)
                            TextField("Dinner, taxi, groceries…", text: $title)
                                .focused($focused, equals: .title)
                                .padding(InpensoTheme.Space.md)
                                .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
                        }

                        if members.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Paid by")
                                    .font(InpensoTheme.label(13))
                                    .foregroundStyle(InpensoTheme.muted)
                                Picker("Paid by", selection: Binding(
                                    get: { paidByMemberID ?? defaultPayerID ?? members.first?.id ?? 0 },
                                    set: { paidByMemberID = $0 }
                                )) {
                                    ForEach(members) { member in
                                        Text(member.name).tag(member.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(InpensoTheme.Space.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(InpensoTheme.body(13))
                                .foregroundStyle(InpensoTheme.danger)
                        }

                        Button(action: save) {
                            if isSaving {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Add expense").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(InpensoPrimaryButtonStyle(enabled: isValid && !isSaving, tint: InpensoTheme.expenseTint))
                        .disabled(!isValid || isSaving)
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.top, InpensoTheme.Space.md)
                    .padding(.bottom, InpensoTheme.Space.xxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                paidByMemberID = defaultPayerID ?? members.first?.id
                focused = .amount
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var currencySymbol: String {
        Locale.current.localizedCurrencySymbol(forCurrencyCode: currency) ?? currency
    }

    private func save() {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        let payer = paidByMemberID ?? defaultPayerID ?? members.first?.id
        guard let payer else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await SharedTripAPI.shared.addExpense(
                    tripID: tripID,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Expense" : title,
                    amount: value,
                    paidByMemberID: payer
                )
                HapticFeedback.success()
                onSaved()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                HapticFeedback.error()
            }
            isSaving = false
        }
    }
}
