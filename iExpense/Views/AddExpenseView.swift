//
//  AddExpenseView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var title: String = ""
    @State private var price: String = ""
    @State private var selectedCategoryID: String
    @State private var transactionType: TransactionType = .expense
    @State private var selectedDate: Date = Date()
    @State private var notes: String = ""
    @State private var showDatePicker = false
    @State private var keyboardVisible: Bool = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var animateSuccess = false
    @State private var showReceiptScan = false
    @State private var saveAsTemplate = false

    private var currencySymbol: String {
        let locale = Locale.current
        let currencyCode = settingsViewModel.selectedCurrency
        return locale.localizedCurrencySymbol(forCurrencyCode: currencyCode) ?? currencyCode
    }

    init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        let defaultCategoryID = UserDefaults.standard.string(forKey: "defaultCategoryID") ?? Category.food.categoryID
        _selectedCategoryID = State(initialValue: defaultCategoryID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground(intensity: 0.65)

                ScrollView {
                    VStack(spacing: 18) {
                        Text("Inpenso")
                            .font(InpensoTheme.brandFont(28, weight: .bold))
                            .foregroundStyle(InpensoTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            showReceiptScan = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.viewfinder")
                                    .foregroundStyle(InpensoTheme.tide)
                                Text("Scan a receipt instead")
                                    .font(InpensoTheme.body(15, weight: .semibold))
                                    .foregroundStyle(InpensoTheme.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(InpensoTheme.muted)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.7))
                            )
                        }
                        .buttonStyle(.plain)

                        mainDataCard

                        CardView(title: "Category") {
                            CategoryGrid(
                                selectedCategoryID: $selectedCategoryID,
                                categories: categoryStore.allCategories
                            )
                            .padding(.horizontal)
                        }

                        DatePickerCard(
                            title: "Date",
                            selectedDate: $selectedDate,
                            isExpanded: $showDatePicker
                        )

                        notesCard

                        if transactionType == .expense {
                            Toggle(isOn: $saveAsTemplate) {
                                Text("Save as quick spend shortcut")
                                    .font(InpensoTheme.body(14, weight: .medium))
                            }
                            .tint(InpensoTheme.tide)
                            .padding(.horizontal, 4)
                        }

                        Button(action: saveExpense) {
                            Text("Save transaction")
                        }
                        .buttonStyle(InpensoPrimaryButtonStyle(enabled: isFormValid()))
                        .disabled(!isFormValid())
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)

                if animateSuccess {
                    successOverlay
                }
            }
            .navigationTitle("New transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(InpensoTheme.slate)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if keyboardVisible {
                        Button("Done") { hideKeyboard() }
                            .foregroundStyle(InpensoTheme.copper)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation { keyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation { keyboardVisible = false }
            }
            .alert(validationMessage, isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
            .sheet(isPresented: $showReceiptScan) {
                ReceiptScanView(viewModel: viewModel)
            }
            .onAppear {
                selectedCategoryID = categoryStore.preferredCategoryID(for: selectedCategoryID)
            }
        }
    }

    private var mainDataCard: some View {
        CardView(title: "Details", showDivider: true) {
            VStack(spacing: 16) {
                Picker("Type", selection: $transactionType) {
                    ForEach(TransactionType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                TextFormField(
                    label: "Title",
                    text: $title,
                    placeholder: transactionType == .expense ? "What did you spend on?" : "Income source",
                    leadingIcon: "pencil"
                )
                .padding(.horizontal)

                CurrencyFormField(
                    label: "Amount",
                    amount: $price,
                    currencySymbol: currencySymbol,
                    clearAction: { price = "" }
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }

    private var notesCard: some View {
        CardView(title: "Notes (optional)") {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.65))
                    .frame(minHeight: 100)

                TextEditor(text: $notes)
                    .font(InpensoTheme.body(15))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
                    .frame(minHeight: 100)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(InpensoTheme.surplus)

                Text("Saved")
                    .font(InpensoTheme.brandFont(24, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(InpensoTheme.foam)
            )
            .scaleEffect(animateSuccess ? 1.0 : 0.5)
            .opacity(animateSuccess ? 1 : 0)
            .animation(.spring(), value: animateSuccess)
        }
    }

    private func isFormValid() -> Bool {
        !title.isEmpty && !price.isEmpty
    }

    private func saveExpense() {
        hideKeyboard()

        if title.isEmpty {
            showValidationAlert("Please enter a title.")
            return
        }

        if price.isEmpty {
            showValidationAlert("Please enter an amount.")
            return
        }

        price = price.replacingOccurrences(of: ",", with: ".")
        guard let priceValue = Double(price) else {
            showValidationAlert("Please enter a valid amount.")
            return
        }

        withAnimation { animateSuccess = true }

        let selectedCategory = categoryStore.category(for: selectedCategoryID)
        let legacyCategory = Category.category(from: selectedCategory.id) ?? .others
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        _ = viewModel.addExpense(
            title: title,
            price: priceValue,
            date: selectedDate,
            category: legacyCategory,
            type: transactionType,
            categoryID: selectedCategory.id,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )

        if saveAsTemplate && transactionType == .expense {
            viewModel.saveTemplate(
                title: title,
                amount: priceValue,
                categoryID: selectedCategory.id,
                category: legacyCategory
            )
        }

        HapticFeedback.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            dismiss()
        }
    }

    private func showValidationAlert(_ message: String) {
        validationMessage = message
        showingValidationAlert = true
        HapticFeedback.error()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Locale {
    func localizedCurrencySymbol(forCurrencyCode currencyCode: String) -> String? {
        NSLocale(localeIdentifier: identifier).displayName(forKey: .currencySymbol, value: currencyCode)
    }
}

#Preview {
    AddExpenseView(viewModel: ExpenseViewModel())
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
