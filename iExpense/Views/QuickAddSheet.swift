//
//  QuickAddSheet.swift
//  iExpense
//
//  Amount-first entry. Expense / Income always at the top.
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
    @State private var showFullForm = false
    @State private var showReceiptScan = false
    @FocusState private var amountFocused: Bool

    private var currencySymbol: String {
        Locale.current.localizedCurrencySymbol(forCurrencyCode: settingsViewModel.selectedCurrency)
            ?? settingsViewModel.selectedCurrency
    }

    private var accent: Color {
        transactionType == .income ? InpensoTheme.incomeTint : InpensoTheme.expenseTint
    }

    private var isValid: Bool {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value > 0 else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                        VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
                            Text("What for?")
                                .font(InpensoTheme.label(13))
                                .foregroundStyle(InpensoTheme.muted)
                            TextField(transactionType == .income ? "Payday, freelance…" : "Coffee, rent…", text: $title)
                                .font(InpensoTheme.body(17, weight: .medium))
                                .foregroundStyle(InpensoTheme.ink)
                                .padding(.horizontal, InpensoTheme.Space.md)
                                .padding(.vertical, InpensoTheme.Space.sm + 2)
                                .background(
                                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                                        .fill(InpensoTheme.mist)
                                )
                        }

                        if transactionType == .expense {
                            categoryStrip
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
            }
            .sheet(isPresented: $showFullForm) {
                AddExpenseView(viewModel: viewModel, initialType: transactionType)
            }
            .sheet(isPresented: $showReceiptScan) {
                ReceiptScanView(viewModel: viewModel)
            }
            .onAppear {
                selectedCategoryID = categoryStore.preferredCategoryID(for: selectedCategoryID)
                amountFocused = true
            }
            .onChange(of: title) { _, newValue in
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
                    .focused($amountFocused)
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

    private var categoryStrip: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text("Category")
                .font(InpensoTheme.label(13))
                .foregroundStyle(InpensoTheme.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: InpensoTheme.Space.xs) {
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
    }

    @ViewBuilder
    private var templatesSection: some View {
        let templates = viewModel.quickTemplates
        if !templates.isEmpty {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                Text("Shortcuts")
                    .font(InpensoTheme.label(13))
                    .foregroundStyle(InpensoTheme.muted)

                FlowWrap(spacing: InpensoTheme.Space.xs) {
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
        }
    }

    private var scanRow: some View {
        Button {
            if pro.canScanReceipt {
                showReceiptScan = true
            } else {
                pro.openPaywall(plan: .yearly)
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
        _ = viewModel.addFromTemplate(template)
        HapticFeedback.success()
        dismiss()
    }

    private func applyMerchantRule(for rawTitle: String) {
        guard pro.isPro else { return }
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

        _ = viewModel.addExpense(
            title: cleanTitle,
            price: price,
            date: Date(),
            category: legacy,
            type: transactionType,
            categoryID: category.id
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

/// Simple wrapping HStack for template chips.
private struct FlowWrap<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        // Fallback: horizontal scroll if many chips — keeps layout simple & reliable
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                content()
            }
        }
    }
}
