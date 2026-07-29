//
//  QuickAddSheet.swift
//  iExpense
//

import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var pro: ProEntitlementManager
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var transactionType: TransactionType
    @State private var amount: String = ""
    @State private var title: String = ""
    @State private var selectedCategoryID: String
    @State private var selectedAccountID: UUID?
    @State private var selectedTags: [String] = []
    @State private var selectedCurrencyCode: String = ""
    @State private var showFullForm = false
    @State private var showReceiptScan = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case amount, title
    }

    private var currencySymbol: String {
        Locale.current.localizedCurrencySymbol(forCurrencyCode: settingsViewModel.selectedCurrency)
            ?? settingsViewModel.selectedCurrency
    }

    private var accent: Color {
        transactionType == .income ? InpensoTheme.incomeTint : InpensoTheme.expenseTint
    }

    private var liquidAccounts: [FinanceAccount] {
        PremiumDataStore.shared.accounts.filter(\.isLiquid)
    }

    private var isValid: Bool {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value > 0 else { return false }
        if transactionType == .income, !liquidAccounts.isEmpty {
            return selectedAccountID != nil
        }
        return true
    }

    init(viewModel: ExpenseViewModel, initialType: TransactionType = .expense) {
        self.viewModel = viewModel
        _transactionType = State(initialValue: initialType)
        let defaultID = UserDefaults.standard.string(forKey: "defaultCategoryID") ?? Category.food.categoryID
        _selectedCategoryID = State(initialValue: defaultID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.xl) {
                        TransactionTypePicker(type: $transactionType)

                        amountBlock

                        titleBlock

                        if transactionType == .income {
                            AccountDestinationPicker(
                                selectedAccountID: $selectedAccountID,
                                currencyCode: settingsViewModel.selectedCurrency
                            )
                        }

                        if transactionType == .expense {
                            categoryWrap
                            TagPickerView(
                                tags: $selectedTags,
                                suggested: Array(viewModel.allUniqueTags).sorted(),
                                isPro: pro.isPro,
                                freeLimit: FreeTierLimits.uniqueTags,
                                onUpgrade: { pro.openPaywall(plan: .yearly) }
                            )
                            currencyQuickPicker
                            templatesSection
                            scanRow
                        }

                        Button(action: saveQuick) {
                            Text(transactionType == .income ? "Add income" : "Add expense")
                        }
                        .buttonStyle(InpensoPrimaryButtonStyle(enabled: isValid, tint: accent))
                        .disabled(!isValid)
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.top, InpensoTheme.Space.md)
                    .padding(.bottom, InpensoTheme.Space.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(transactionType == .income ? "New income" : "New expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Full form") { showFullForm = true }
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    if focusedField == .amount {
                        Button("Next") {
                            focusedField = .title
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Done") {
                            focusedField = nil
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showFullForm) {
                AddExpenseView(viewModel: viewModel, initialType: transactionType)
            }
            .sheet(isPresented: $showReceiptScan) {
                ReceiptScanView(viewModel: viewModel)
            }
            .onAppear {
                selectedCategoryID = categoryStore.preferredCategoryID(for: selectedCategoryID)
                if selectedAccountID == nil {
                    selectedAccountID = PremiumDataStore.shared.primaryLiquidAccount?.id
                }
                if selectedCurrencyCode.isEmpty {
                    selectedCurrencyCode = settingsViewModel.selectedCurrency
                }
                focusedField = .amount
            }
            .onChange(of: transactionType) { _, newType in
                if newType == .income, selectedAccountID == nil {
                    selectedAccountID = PremiumDataStore.shared.primaryLiquidAccount?.id
                }
            }
            .onChange(of: title) { _, newValue in
                applyNaturalLanguage(from: newValue)
                applyMerchantRule(for: newValue)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
            Text("Amount")
                .font(InpensoTheme.label(13))
                .foregroundStyle(InpensoTheme.muted)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currencySymbol)
                    .font(InpensoTheme.displayAmount(28))
                    .foregroundStyle(InpensoTheme.muted)

                TextField("0.00", text: $amount)
                    .font(InpensoTheme.displayAmount(40))
                    .foregroundStyle(InpensoTheme.ink)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .tint(accent)
                    .onChange(of: amount) { _, newValue in
                        amount = formatCurrencyInput(newValue)
                    }
            }
            .padding(.vertical, InpensoTheme.Space.sm)
        }
        .padding(InpensoTheme.Space.md)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.xl)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
            HStack {
                Text("What for?")
                    .font(InpensoTheme.label(13))
                    .foregroundStyle(InpensoTheme.muted)
                Text("Optional")
                    .font(InpensoTheme.label(11, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted.opacity(0.8))
            }
                TextField(
                transactionType == .income ? "Payday, freelance…" : "Coffee 4.50 or Coffee…",
                text: $title
            )
            .font(InpensoTheme.body(17, weight: .medium))
            .foregroundStyle(InpensoTheme.ink)
            .focused($focusedField, equals: .title)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
            .padding(.horizontal, InpensoTheme.Space.md)
            .padding(.vertical, InpensoTheme.Space.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(InpensoTheme.mist)
            )
        }
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

    @ViewBuilder
    private var templatesSection: some View {
        let templates = viewModel.quickTemplates
        if !templates.isEmpty || !pro.isPro {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                HStack {
                    Text("Shortcuts")
                        .font(InpensoTheme.label(13))
                        .foregroundStyle(InpensoTheme.muted)
                    if !pro.isPro {
                        Text("Pro")
                            .font(InpensoTheme.label(10, weight: .bold))
                            .foregroundStyle(InpensoTheme.tide)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(InpensoTheme.tide.opacity(0.12), in: Capsule())
                    }
                }

                if pro.isPro {
                    if templates.isEmpty {
                        Text("Save frequent expenses from the full form.")
                            .font(InpensoTheme.body(13))
                            .foregroundStyle(InpensoTheme.muted)
                    } else {
                        FlowLayout(spacing: InpensoTheme.Space.xs, lineSpacing: InpensoTheme.Space.xs) {
                            ForEach(templates) { template in
                                Button {
                                    applyTemplate(template)
                                } label: {
                                    Text(template.title)
                                        .font(InpensoTheme.label(13, weight: .medium))
                                        .foregroundStyle(InpensoTheme.ink)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                                .fill(InpensoTheme.mist)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Button {
                        pro.openPaywall(plan: .yearly)
                    } label: {
                        HStack {
                            Text("Unlock one-tap shortcuts with Pro")
                                .font(InpensoTheme.body(14, weight: .medium))
                                .foregroundStyle(InpensoTheme.ink)
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundStyle(InpensoTheme.muted)
                        }
                        .padding(InpensoTheme.Space.md)
                        .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scanRow: some View {
        Button {
            if pro.canScanReceipt {
                showReceiptScan = true
            } else {
                pro.openPaywall(plan: .yearly)
                pro.notifyLimitHit()
            }
        } label: {
            HStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan a receipt")
                        .font(InpensoTheme.body(15, weight: .medium))
                        .foregroundStyle(InpensoTheme.ink)
                    Text(pro.isPro ? "Unlimited OCR" : "\(pro.receiptScansRemaining) free left")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(InpensoTheme.Space.md)
            .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
        }
        .buttonStyle(.plain)
    }

    private func applyTemplate(_ template: QuickSpendTemplate) {
        guard pro.isPro else {
            pro.openPaywall(plan: .yearly)
            return
        }
        _ = viewModel.addFromTemplate(template)
        HapticFeedback.success()
        dismiss()
    }

    private var currencyQuickPicker: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
            Text("Currency")
                .font(InpensoTheme.label(13))
                .foregroundStyle(InpensoTheme.muted)
            Picker("Currency", selection: $selectedCurrencyCode) {
                ForEach(availableCurrencies, id: \.code) { currency in
                    Text("\(currency.code) \(currency.symbol)").tag(currency.code)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, InpensoTheme.Space.md)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
        }
    }

    private func applyNaturalLanguage(from rawTitle: String) {
        guard let draft = NaturalLanguageExpenseParser.parse(rawTitle, categoryStore: categoryStore) else { return }
        // Only auto-fill amount when the field is empty or still matches a prior parse.
        if amount.isEmpty || Double(amount.replacingOccurrences(of: ",", with: ".")) == nil {
            amount = String(format: "%.2f", draft.amount)
            title = draft.title
        } else if abs((Double(amount.replacingOccurrences(of: ",", with: ".")) ?? -1) - draft.amount) < 0.001 {
            title = draft.title
        }
        if let categoryID = draft.suggestedCategoryID {
            selectedCategoryID = categoryID
        }
    }

    private func applyMerchantRule(for rawTitle: String) {
        // Starter rules work for everyone; custom rules require Pro for editing only.
        if let categoryID = PremiumDataStore.shared.suggestedCategoryID(forTitle: rawTitle) {
            selectedCategoryID = categoryID
        }
    }

    private func saveQuick() {
        guard isValid,
              let price = Double(amount.replacingOccurrences(of: ",", with: ".")),
              price > 0 else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = transactionType == .income
            ? FinanceCategory.builtIn(for: .others)
            : categoryStore.category(for: selectedCategoryID)
        let legacy = Category.category(from: category.id) ?? .others
        let resolvedTitle = cleanTitle.isEmpty ? category.displayName : cleanTitle

        let tags = Expense.normalizedTags(selectedTags)
        if !pro.canUseTag(existingUniqueTags: viewModel.allUniqueTags, newTags: tags) {
            pro.openPaywall(plan: .yearly)
            pro.notifyLimitHit()
            return
        }

        let currency = selectedCurrencyCode.isEmpty ? settingsViewModel.selectedCurrency : selectedCurrencyCode
        let home = settingsViewModel.selectedCurrency
        let rate: Double? = currency.uppercased() == home.uppercased()
            ? nil
            : ExchangeRateService.rate(from: currency, to: home)

        _ = viewModel.addExpense(
            title: resolvedTitle,
            price: price,
            date: Date(),
            category: legacy,
            type: transactionType,
            categoryID: category.id,
            accountID: transactionType == .income ? selectedAccountID : nil,
            tags: tags,
            currencyCode: currency,
            exchangeRateToHome: rate
        )
        HapticFeedback.success()
        dismiss()
    }

    private func formatCurrencyInput(_ input: String) -> String {
        var formatted = input.replacingOccurrences(of: ",", with: ".")
        let parts = formatted.components(separatedBy: ".")
        if parts.count > 2 {
            formatted = parts[0] + "." + parts[1]
        }
        if let decimalIndex = formatted.firstIndex(of: ".") {
            let maxLength = formatted.distance(from: formatted.startIndex, to: decimalIndex) + 3
            if formatted.count > maxLength {
                let end = formatted.index(formatted.startIndex, offsetBy: maxLength)
                formatted = String(formatted[..<end])
            }
        }
        return formatted
    }
}
