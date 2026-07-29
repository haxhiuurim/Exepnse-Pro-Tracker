//
//  EditExpenseView.swift
//  iExpense
//

import SwiftUI

struct EditExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var pro: ProEntitlementManager
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var title: String
    @State private var price: String
    @State private var selectedDate: Date
    @State private var selectedCategoryID: String
    @State private var transactionType: TransactionType
    @State private var showDatePicker: Bool = false
    @State private var notes: String = ""
    @State private var selectedTags: [String] = []
    @State private var selectedCurrencyCode: String = ""
    @State private var keyboardVisible: Bool = false
    @State private var viewID = UUID()
    let expense: Expense

    init(viewModel: ExpenseViewModel, expense: Expense) {
        self.viewModel = viewModel
        self.expense = expense
        _title = State(initialValue: expense.title)
        _price = State(initialValue: String(format: "%.2f", expense.price))
        _selectedDate = State(initialValue: expense.date)
        _selectedCategoryID = State(initialValue: expense.categoryID)
        _transactionType = State(initialValue: expense.type)
        _notes = State(initialValue: expense.notes ?? "")
        _selectedTags = State(initialValue: expense.tags)
        _selectedCurrencyCode = State(initialValue: expense.currencyCode ?? "")
    }

    private var currencySymbol: String {
        let code = selectedCurrencyCode.isEmpty ? settingsViewModel.selectedCurrency : selectedCurrencyCode
        return Locale.current.localizedCurrencySymbol(forCurrencyCode: code) ?? code
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView {
                    VStack(spacing: InpensoTheme.Space.section) {
                        TransactionTypePicker(type: $transactionType)

                        VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
                            Text("Amount")
                                .font(InpensoTheme.label(11, weight: .semibold))
                                .foregroundStyle(InpensoTheme.muted)
                            CurrencyFormField(
                                label: "",
                                amount: $price,
                                currencySymbol: currencySymbol
                            )
                        }

                        CardView(title: "Details") {
                            TextFormField(
                                label: "Title",
                                text: $title,
                                placeholder: transactionType == .expense ? "Expense title" : "Income title"
                            )
                            .padding(.horizontal, InpensoTheme.Space.md)
                        }

                        DatePickerCard(
                            title: "Date",
                            selectedDate: $selectedDate,
                            isExpanded: $showDatePicker
                        )

                        if transactionType == .expense {
                            CardView(title: "Category") {
                                CategoryGrid(
                                    selectedCategoryID: $selectedCategoryID,
                                    categories: categoryStore.categoriesForPicker(including: selectedCategoryID)
                                )
                            }

                            TagPickerView(
                                tags: $selectedTags,
                                suggested: Array(viewModel.allUniqueTags).sorted(),
                                isPro: pro.isPro,
                                freeLimit: FreeTierLimits.uniqueTags,
                                onUpgrade: { pro.openPaywall(plan: .yearly) }
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Currency")
                                    .font(InpensoTheme.label(13))
                                    .foregroundStyle(InpensoTheme.muted)
                                Picker("Currency", selection: $selectedCurrencyCode) {
                                    Text(settingsViewModel.selectedCurrency).tag("")
                                    ForEach(availableCurrencies, id: \.code) { currency in
                                        Text("\(currency.code)").tag(currency.code)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(InpensoTheme.Space.md)
                                .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
                            }
                        }

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

                        VStack(spacing: InpensoTheme.Space.sm) {
                            Button {
                                hideKeyboard()
                                saveChanges()
                                HapticFeedback.success()
                                dismiss()
                            } label: {
                                Text("Save Changes")
                            }
                            .buttonStyle(
                                InpensoPrimaryButtonStyle(
                                    tint: transactionType == .income ? InpensoTheme.incomeTint : InpensoTheme.ink
                                )
                            )

                            Button {
                                hideKeyboard()
                                deleteExpense()
                                HapticFeedback.impact(style: .medium)
                                dismiss()
                            } label: {
                                Text("Delete Transaction")
                            }
                            .buttonStyle(InpensoSecondaryButtonStyle())
                            .foregroundStyle(InpensoTheme.danger)
                        }
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.bottom, InpensoTheme.Space.section)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .id(viewID)
            .navigationTitle("Edit Transaction")
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
            .onAppear { viewID = UUID() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation { keyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation { keyboardVisible = false }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func saveChanges() {
        guard let priceValue = Double(price.replacingOccurrences(of: ",", with: ".")) else { return }

        let tags = Expense.normalizedTags(selectedTags)
        if !pro.canUseTag(existingUniqueTags: viewModel.allUniqueTags.subtracting(expense.tags), newTags: tags) {
            pro.openPaywall(plan: .yearly)
            pro.notifyLimitHit()
            return
        }

        let selectedCategory = categoryStore.category(for: selectedCategoryID)
        let currency = selectedCurrencyCode.isEmpty ? settingsViewModel.selectedCurrency : selectedCurrencyCode
        let home = settingsViewModel.selectedCurrency
        let rate: Double? = currency.uppercased() == home.uppercased()
            ? nil
            : ExchangeRateService.rate(from: currency, to: home)

        var updated = expense
        updated.title = title
        updated.price = priceValue
        updated.date = selectedDate
        updated.type = transactionType
        updated.categoryID = selectedCategory.id
        updated.category = Category.category(from: selectedCategory.id) ?? .others
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        updated.tags = tags
        updated.currencyCode = currency
        updated.exchangeRateToHome = rate
        viewModel.updateExpense(updated)
    }

    private func deleteExpense() {
        viewModel.deleteExpenses([expense])
    }
}

#Preview {
    EditExpenseView(
        viewModel: ExpenseViewModel(),
        expense: Expense(title: "Sample", price: 10, date: Date(), category: .food)
    )
    .environmentObject(SettingsViewModel())
    .environmentObject(CategoryStore())
}
