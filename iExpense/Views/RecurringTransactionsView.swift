//
//  RecurringTransactionsView.swift
//  iExpense
//

import SwiftUI

struct RecurringTransactionsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var pro: ProEntitlementManager
    @ObservedObject var expenseViewModel: ExpenseViewModel
    @ObservedObject private var service = RecurringTransactionService.shared

    @State private var showingEditor = false
    @State private var editingItem: RecurringTransaction?
    @State private var showLimitAlert = false

    private var currencyCode: String { settingsViewModel.selectedCurrency }

    var body: some View {
        ZStack {
            AtmosphereBackground(intensity: 0.55)

            List {
                Section {
                    Text(pro.isPro
                         ? "Rent, subscriptions, and paychecks can post automatically on schedule."
                         : "Free includes \(FreeTierLimits.recurringItems) recurring items. Pro unlocks unlimited + a 30-day calendar.")
                        .font(InpensoTheme.body(13))
                        .foregroundStyle(InpensoTheme.muted)
                        .listRowBackground(Color.clear)
                }

                if !pro.isPro {
                    Section {
                        ProGateBanner(message: "\(service.items.count)/\(FreeTierLimits.recurringItems) free recurring slots used.") {
                            pro.openPaywall()
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                if pro.isPro {
                    Section {
                        NavigationLink {
                            UpcomingRecurringCalendarView()
                        } label: {
                            Label("Upcoming this month", systemImage: "calendar")
                        }
                    }
                }

                if service.items.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 36))
                                .foregroundStyle(InpensoTheme.tide)
                            Text("No recurring items yet")
                                .font(InpensoTheme.body(15, weight: .semibold))
                                .foregroundStyle(InpensoTheme.ink)
                            Text("Add rent, Netflix, salary — anything that repeats.")
                                .font(InpensoTheme.body(13))
                                .foregroundStyle(InpensoTheme.muted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.white.opacity(0.55))
                    }
                } else {
                    Section("Active & upcoming") {
                        ForEach(service.items) { item in
                            Button {
                                editingItem = item
                                showingEditor = true
                            } label: {
                                recurringRow(item)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    service.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    service.toggleActive(item)
                                } label: {
                                    Label(item.isActive ? "Pause" : "Resume", systemImage: item.isActive ? "pause.fill" : "play.fill")
                                }
                                .tint(InpensoTheme.tide)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if editingItem == nil && !pro.canAddRecurring(currentCount: service.items.count) {
                        showLimitAlert = true
                        return
                    }
                    editingItem = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(InpensoTheme.copper)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            RecurringEditorSheet(
                existing: editingItem,
                onSave: { item in
                    if editingItem == nil && !pro.canAddRecurring(currentCount: service.items.count) {
                        showLimitAlert = true
                        return
                    }
                    service.upsert(item)
                    _ = service.processDueTransactions(into: expenseViewModel)
                }
            )
            .environmentObject(settingsViewModel)
            .environmentObject(categoryStore)
        }
        .alert("Free limit reached", isPresented: $showLimitAlert) {
            Button("Upgrade") { pro.openPaywall() }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Free plans include \(FreeTierLimits.recurringItems) recurring items. Upgrade for unlimited + calendar.")
        }
        .onAppear {
            service.reload()
            _ = service.processDueTransactions(into: expenseViewModel)
        }
    }

    private func recurringRow(_ item: RecurringTransaction) -> some View {
        let category = categoryStore.category(for: item.categoryID)
        return HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(category.color)
                .frame(width: 36, height: 36)
                .background(category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Text("\(item.frequency.displayName) · next \(item.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(InpensoTheme.label(12))
                    .foregroundStyle(item.isActive ? InpensoTheme.muted : InpensoTheme.danger)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.amount, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(15))
                    .foregroundStyle(item.type == .income ? InpensoTheme.positive : InpensoTheme.ink)
                if !item.isActive {
                    Text("Paused")
                        .font(InpensoTheme.label(10, weight: .bold))
                        .foregroundStyle(InpensoTheme.danger)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecurringEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore

    let existing: RecurringTransaction?
    let onSave: (RecurringTransaction) -> Void

    @State private var title: String = ""
    @State private var amount: String = ""
    @State private var categoryID: String = Category.rent.categoryID
    @State private var type: TransactionType = .expense
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var startDate: Date = Date()
    @State private var hasEndDate = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var notes: String = ""

    private var currencySymbol: String {
        Locale.current.localizedCurrencySymbol(forCurrencyCode: settingsViewModel.selectedCurrency)
            ?? settingsViewModel.selectedCurrency
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground(intensity: 0.5)
                Form {
                    Section("Details") {
                        TextField("Title", text: $title)
                        HStack {
                            Text(currencySymbol)
                                .foregroundStyle(InpensoTheme.tide)
                            TextField("Amount", text: $amount)
                                .keyboardType(.decimalPad)
                        }
                        Picker("Type", selection: $type) {
                            ForEach(TransactionType.allCases) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Schedule") {
                        Picker("Repeats", selection: $frequency) {
                            ForEach(RecurrenceFrequency.allCases) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                        Toggle("End date", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker("Ends", selection: $endDate, displayedComponents: .date)
                        }
                    }

                    Section("Category") {
                        Picker("Category", selection: $categoryID) {
                            ForEach(categoryStore.allCategories) { category in
                                Text(category.displayName).tag(category.id)
                            }
                        }
                    }

                    Section("Notes") {
                        TextField("Optional", text: $notes)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(existing == nil ? "New recurring" : "Edit recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .foregroundStyle(InpensoTheme.copper)
                }
            }
            .onAppear {
                if let existing {
                    title = existing.title
                    amount = String(format: "%.2f", existing.amount)
                    categoryID = existing.categoryID
                    type = existing.type
                    frequency = existing.frequency
                    startDate = existing.startDate
                    hasEndDate = existing.endDate != nil
                    endDate = existing.endDate ?? endDate
                    notes = existing.notes ?? ""
                } else {
                    categoryID = categoryStore.preferredCategoryID(for: Category.rent.categoryID)
                }
            }
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private func save() {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        let category = categoryStore.category(for: categoryID)
        let legacy = Category.category(from: categoryID) ?? .others
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let item = RecurringTransaction(
            id: existing?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: value,
            categoryID: category.id,
            category: legacy,
            type: type,
            frequency: frequency,
            startDate: startDate,
            nextDueDate: existing?.nextDueDate ?? startDate,
            endDate: hasEndDate ? endDate : nil,
            isActive: existing?.isActive ?? true,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            lastGeneratedDate: existing?.lastGeneratedDate
        )
        onSave(item)
        HapticFeedback.success()
        dismiss()
    }
}
