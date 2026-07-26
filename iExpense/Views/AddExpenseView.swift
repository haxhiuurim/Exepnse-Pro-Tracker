//
//  AddExpenseView.swift
//  iExpense
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var title: String = ""
    @State private var price: String = ""
    @State private var selectedCategoryID: String
    @State private var transactionType: TransactionType
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

    init(viewModel: ExpenseViewModel, initialType: TransactionType = .expense) {
        self.viewModel = viewModel
        _transactionType = State(initialValue: initialType)
        let defaultCategoryID = UserDefaults.standard.string(forKey: "defaultCategoryID") ?? Category.food.categoryID
        _selectedCategoryID = State(initialValue: defaultCategoryID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView {
                    VStack(spacing: InpensoTheme.Space.section) {
                        TransactionTypePicker(type: $transactionType)

                        amountSection

                        detailsSection

                        if transactionType == .expense {
                            receiptScanLink
                            categorySection
                        }

                        DatePickerCard(
                            title: "Date",
                            selectedDate: $selectedDate,
                            isExpanded: $showDatePicker
                        )

                        notesSection

                        if transactionType == .expense {
                            templateToggle
                        }

                        saveButton
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, InpensoTheme.Space.section)
                }
                .scrollDismissesKeyboard(.interactively)

                if animateSuccess { successOverlay }
            }
            .navigationTitle("New Transaction")
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

    // MARK: - Sections

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
            Text("Amount")
                .font(InpensoTheme.label(11, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)

            CurrencyFormField(
                label: "",
                amount: $price,
                currencySymbol: currencySymbol,
                clearAction: { price = "" }
            )
        }
    }

    private var detailsSection: some View {
        CardView(title: "Details") {
            TextFormField(
                label: "Title",
                text: $title,
                placeholder: transactionType == .expense ? "What did you spend on?" : "Income source"
            )
            .padding(.horizontal, InpensoTheme.Space.md)
        }
    }

    private var receiptScanLink: some View {
        Button { showReceiptScan = true } label: {
            HStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
                Text("Scan receipt")
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(InpensoTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .fill(InpensoTheme.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                            .stroke(InpensoTheme.hairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var categorySection: some View {
        CardView(title: "Category") {
            CategoryGrid(
                selectedCategoryID: $selectedCategoryID,
                categories: categoryStore.allCategories
            )
        }
    }

    private var notesSection: some View {
        CardView(title: "Notes") {
            TextEditor(text: $notes)
                .font(InpensoTheme.body(15))
                .foregroundStyle(InpensoTheme.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 88)
                .padding(InpensoTheme.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                        .fill(InpensoTheme.mist)
                )
                .padding(.horizontal, InpensoTheme.Space.md)
        }
    }

    private var templateToggle: some View {
        Toggle(isOn: $saveAsTemplate) {
            Text("Save as shortcut")
                .font(InpensoTheme.body(14, weight: .medium))
                .foregroundStyle(InpensoTheme.ink)
        }
        .tint(InpensoTheme.ink)
    }

    private var saveButton: some View {
        Button(action: saveExpense) {
            Text(transactionType == .income ? "Save Income" : "Save Expense")
        }
        .buttonStyle(
            InpensoPrimaryButtonStyle(
                enabled: isFormValid(),
                tint: transactionType == .income ? InpensoTheme.incomeTint : InpensoTheme.expenseTint
            )
        )
        .disabled(!isFormValid())
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(InpensoTheme.surplus)
                Text("Saved")
                    .font(InpensoTheme.brandFont(20, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
            }
            .padding(InpensoTheme.Space.xl)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .fill(InpensoTheme.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                            .stroke(InpensoTheme.hairline, lineWidth: 1)
                    )
            )
            .scaleEffect(animateSuccess ? 1 : 0.85)
            .opacity(animateSuccess ? 1 : 0)
            .animation(InpensoTheme.Motion.gentle, value: animateSuccess)
        }
    }

    // MARK: - Actions

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
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
