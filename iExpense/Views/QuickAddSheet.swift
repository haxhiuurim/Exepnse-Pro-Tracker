//
//  QuickAddSheet.swift
//  iExpense
//
//  Fast path for logging spend — amount-first, templates, receipt scan.
//

import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var amount: String = ""
    @State private var title: String = ""
    @State private var selectedCategoryID: String
    @State private var showFullForm = false
    @State private var showReceiptScan = false
    @State private var showSaveAsTemplate = false
    @State private var animateIn = false
    @FocusState private var amountFocused: Bool

    private var currencySymbol: String {
        Locale.current.localizedCurrencySymbol(forCurrencyCode: settingsViewModel.selectedCurrency)
            ?? settingsViewModel.selectedCurrency
    }

    init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        let defaultID = UserDefaults.standard.string(forKey: "defaultCategoryID") ?? Category.food.categoryID
        _selectedCategoryID = State(initialValue: defaultID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground(intensity: 0.7)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        brandHeader
                        amountHero
                        categoryStrip
                        titleField
                        templatesSection
                        actionRow
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 18)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(InpensoTheme.slate)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFullForm = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(InpensoTheme.ink)
                    }
                    .accessibilityLabel("More options")
                }
            }
            .sheet(isPresented: $showFullForm) {
                AddExpenseView(viewModel: viewModel)
            }
            .sheet(isPresented: $showReceiptScan) {
                ReceiptScanView(viewModel: viewModel)
            }
            .onAppear {
                selectedCategoryID = categoryStore.preferredCategoryID(for: selectedCategoryID)
                amountFocused = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05)) {
                    animateIn = true
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Inpenso")
                .font(InpensoTheme.brandFont(34, weight: .bold))
                .foregroundStyle(InpensoTheme.ink)
            Text("Capture a spend in seconds.")
                .font(InpensoTheme.body(15))
                .foregroundStyle(InpensoTheme.muted)
        }
    }

    private var amountHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AMOUNT")
                .font(InpensoTheme.label(11, weight: .bold))
                .foregroundStyle(InpensoTheme.muted)
                .tracking(1.2)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currencySymbol)
                    .font(InpensoTheme.displayAmount(36))
                    .foregroundStyle(InpensoTheme.tide)

                TextField("0.00", text: $amount)
                    .font(InpensoTheme.displayAmount(48))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .foregroundStyle(InpensoTheme.ink)
            }
            .padding(.vertical, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [InpensoTheme.foam, InpensoTheme.mist],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(InpensoTheme.tide.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var categoryStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(InpensoTheme.slate)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categoryStore.allCategories) { category in
                        Button {
                            HapticFeedback.selection()
                            selectedCategoryID = category.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(category.displayName)
                                    .font(InpensoTheme.label(12, weight: .semibold))
                            }
                            .foregroundStyle(selectedCategoryID == category.id ? .white : InpensoTheme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedCategoryID == category.id ? category.color : InpensoTheme.ink.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What for?")
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(InpensoTheme.slate)

            TextField("Coffee, groceries, taxi…", text: $title)
                .font(InpensoTheme.body(16, weight: .medium))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(InpensoTheme.ink.opacity(0.08), lineWidth: 1)
                        )
                )
        }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick spends")
                    .font(InpensoTheme.label(13, weight: .semibold))
                    .foregroundStyle(InpensoTheme.slate)
                Spacer()
                if canSaveCurrentAsTemplate {
                    Button("Save shortcut") {
                        saveCurrentAsTemplate()
                    }
                    .font(InpensoTheme.label(12, weight: .bold))
                    .foregroundStyle(InpensoTheme.copper)
                }
            }

            if viewModel.quickTemplates.isEmpty {
                Text("Save frequent spends for one-tap logging.")
                    .font(InpensoTheme.body(13))
                    .foregroundStyle(InpensoTheme.muted)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(viewModel.quickTemplates.prefix(6)) { template in
                        Button {
                            useTemplate(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(template.title)
                                    .font(InpensoTheme.body(14, weight: .semibold))
                                    .foregroundStyle(InpensoTheme.ink)
                                    .lineLimit(1)
                                Text(template.amount, format: .currency(code: settingsViewModel.selectedCurrency))
                                    .font(InpensoTheme.displayAmount(18))
                                    .foregroundStyle(InpensoTheme.tide)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.75))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(InpensoTheme.ink.opacity(0.06), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.removeTemplate(template)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        Button {
            showReceiptScan = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(InpensoTheme.tide.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundStyle(InpensoTheme.tide)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan receipt")
                        .font(InpensoTheme.body(15, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                    Text("Photo a receipt to auto-fill items & total")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                }
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
    }

    private var saveButton: some View {
        Button(action: saveQuick) {
            Text("Add spend")
        }
        .buttonStyle(InpensoPrimaryButtonStyle(enabled: isValid))
        .disabled(!isValid)
    }

    // MARK: - Logic

    private var isValid: Bool {
        parsedAmount != nil && parsedAmount! > 0 && !resolvedTitle.isEmpty
    }

    private var canSaveCurrentAsTemplate: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        return !resolvedTitle.isEmpty
    }

    private var parsedAmount: Double? {
        Double(amount.replacingOccurrences(of: ",", with: "."))
    }

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return categoryStore.category(for: selectedCategoryID).displayName
    }

    private func saveQuick() {
        guard let price = parsedAmount, price > 0 else { return }
        let category = categoryStore.category(for: selectedCategoryID)
        let legacy = Category.category(from: category.id) ?? .others

        _ = viewModel.addExpense(
            title: resolvedTitle,
            price: price,
            date: Date(),
            category: legacy,
            type: .expense,
            categoryID: category.id
        )
        HapticFeedback.success()
        dismiss()
    }

    private func useTemplate(_ template: QuickSpendTemplate) {
        _ = viewModel.addFromTemplate(template)
        HapticFeedback.success()
        dismiss()
    }

    private func saveCurrentAsTemplate() {
        guard let price = parsedAmount, price > 0 else { return }
        let category = categoryStore.category(for: selectedCategoryID)
        let legacy = Category.category(from: category.id) ?? .others
        viewModel.saveTemplate(
            title: resolvedTitle,
            amount: price,
            categoryID: category.id,
            category: legacy
        )
        HapticFeedback.success()
        showSaveAsTemplate = true
    }
}
