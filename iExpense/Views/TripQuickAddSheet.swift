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
    @EnvironmentObject private var categoryStore: CategoryStore
    @State private var amount = ""
    @State private var title = ""
    @State private var paidByMemberID: Int?
    @State private var splitMemberIDs: Set<Int> = []
    @State private var selectedCategoryID: String = FinanceCategory.fallback.id
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    private enum Field { case amount, title }

    private var isValid: Bool {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value > 0 else { return false }
        guard (paidByMemberID ?? defaultPayerID ?? members.first?.id) != nil else { return false }
        return !splitMemberIDs.isEmpty
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

                        categoryWrap

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

                        splitWithSection

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
                splitMemberIDs = Set(members.map(\.id))
                selectedCategoryID = categoryStore.preferredCategoryID(for: selectedCategoryID)
                focused = .amount
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var categoryWrap: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text("Category")
                .font(InpensoTheme.label(13))
                .foregroundStyle(InpensoTheme.muted)

            FlowLayout(spacing: InpensoTheme.Space.xs, lineSpacing: InpensoTheme.Space.xs) {
                ForEach(categoryStore.visibleCategories) { category in
                    let selected = selectedCategoryID == category.id
                    Button {
                        HapticFeedback.selection()
                        selectedCategoryID = category.id
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 12, weight: .semibold))
                            Text(category.displayName)
                                .font(InpensoTheme.label(13, weight: .semibold))
                        }
                        .foregroundStyle(selected ? .white : InpensoTheme.slate)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                .fill(selected ? category.color : InpensoTheme.mist)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var splitWithSection: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            HStack {
                Text("Split with")
                    .font(InpensoTheme.label(13))
                    .foregroundStyle(InpensoTheme.muted)
                Spacer()
                Button(splitMemberIDs.count == members.count ? "Clear" : "Select all") {
                    if splitMemberIDs.count == members.count {
                        splitMemberIDs = Set([paidByMemberID ?? defaultPayerID ?? members.first?.id].compactMap { $0 })
                    } else {
                        splitMemberIDs = Set(members.map(\.id))
                    }
                }
                .font(InpensoTheme.label(12, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
            }

            FlowLayout(spacing: InpensoTheme.Space.xs, lineSpacing: InpensoTheme.Space.xs) {
                ForEach(members) { member in
                    let selected = splitMemberIDs.contains(member.id)
                    Button {
                        HapticFeedback.selection()
                        toggleSplit(member.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12, weight: .semibold))
                            Text(member.name)
                                .font(InpensoTheme.label(13, weight: .semibold))
                        }
                        .foregroundStyle(selected ? .white : InpensoTheme.slate)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                .fill(selected ? InpensoTheme.tide : InpensoTheme.mist)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleSplit(_ memberID: Int) {
        if splitMemberIDs.contains(memberID) {
            guard splitMemberIDs.count > 1 else { return }
            splitMemberIDs.remove(memberID)
        } else {
            splitMemberIDs.insert(memberID)
        }
    }

    private var currencySymbol: String {
        Locale.current.localizedCurrencySymbol(forCurrencyCode: currency) ?? currency
    }

    private func save() {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        let payer = paidByMemberID ?? defaultPayerID ?? members.first?.id
        guard let payer else { return }
        guard !splitMemberIDs.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        let category = categoryStore.category(for: selectedCategoryID)
        Task {
            do {
                try await SharedTripAPI.shared.addExpense(
                    tripID: tripID,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Expense" : title,
                    amount: value,
                    paidByMemberID: payer,
                    splitMemberIDs: Array(splitMemberIDs),
                    categoryID: category.id,
                    categoryName: category.displayName
                )
                try? await SharedTripAPI.shared.heartbeat(markDataChange: true)
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
