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

    private let listRowInsets = EdgeInsets(
        top: InpensoTheme.Space.sm,
        leading: InpensoTheme.Space.screen,
        bottom: InpensoTheme.Space.sm,
        trailing: InpensoTheme.Space.screen
    )

    var body: some View {
        List {
            introSection

            if !pro.isPro {
                proLimitSection
            }

            if pro.isPro {
                calendarSection
            }

            if service.items.isEmpty {
                emptySection
            } else {
                itemsSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AtmosphereBackground())
        .listRowSeparatorTint(InpensoTheme.hairline)
        .navigationTitle("Recurring")
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(InpensoTheme.ink)
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
                        .foregroundStyle(InpensoTheme.ink)
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

    // MARK: - Sections

    private var introSection: some View {
        Section {
            Text(pro.isPro
                 ? "Automatic posting for rent, subscriptions, and paychecks."
                 : "Free plan: \(FreeTierLimits.recurringItems) items. Pro adds unlimited items and a calendar view.")
                .font(InpensoTheme.body(13))
                .foregroundStyle(InpensoTheme.muted)
                .listRowInsets(EdgeInsets(
                    top: InpensoTheme.Space.sm,
                    leading: InpensoTheme.Space.screen,
                    bottom: InpensoTheme.Space.sm,
                    trailing: InpensoTheme.Space.screen
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private var proLimitSection: some View {
        Section {
            ProGateBanner(message: "\(service.items.count)/\(FreeTierLimits.recurringItems) free slots used.") {
                pro.openPaywall()
            }
            .listRowInsets(EdgeInsets(
                top: 0,
                leading: InpensoTheme.Space.screen,
                bottom: InpensoTheme.Space.sm,
                trailing: InpensoTheme.Space.screen
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var calendarSection: some View {
        Section {
            NavigationLink {
                UpcomingRecurringCalendarView()
            } label: {
                Label("Upcoming this month", systemImage: "calendar")
            }
            .listRowInsets(listRowInsets)
            .listRowBackground(InpensoTheme.panelFill)
        } header: {
            sectionHeader("Calendar")
        }
    }

    private var emptySection: some View {
        Section {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
                Text("No recurring items")
                    .font(InpensoTheme.sectionLabel())
                    .foregroundStyle(InpensoTheme.ink)
                Text("Add rent, subscriptions, salary, or any repeating transaction.")
                    .font(InpensoTheme.body(13))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, InpensoTheme.Space.lg)
            .listRowInsets(EdgeInsets(
                top: InpensoTheme.Space.sm,
                leading: InpensoTheme.Space.screen,
                bottom: InpensoTheme.Space.sm,
                trailing: InpensoTheme.Space.screen
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var itemsSection: some View {
        Section {
            ForEach(service.items) { item in
                Button {
                    editingItem = item
                    showingEditor = true
                } label: {
                    recurringRow(item)
                }
                .buttonStyle(.plain)
                .listRowInsets(listRowInsets)
                .listRowBackground(InpensoTheme.panelFill)
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
        } header: {
            sectionHeader("Items")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(InpensoTheme.sectionLabel())
            .foregroundStyle(InpensoTheme.muted)
            .padding(.horizontal, InpensoTheme.Space.screen)
            .padding(.vertical, InpensoTheme.Space.xs)
            .textCase(.none)
            .listRowInsets(EdgeInsets())
            .background(InpensoTheme.foam)
    }

    private func recurringRow(_ item: RecurringTransaction) -> some View {
        let category = categoryStore.category(for: item.categoryID)
        let amountFormatted = item.amount.formatted(.currency(code: currencyCode))
        let signedAmount = item.type == .income ? "+\(amountFormatted)" : "−\(amountFormatted)"

        return HStack(spacing: InpensoTheme.Space.sm) {
            Image(systemName: category.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(category.color)
                .frame(width: 40, height: 40)
                .background(
                    category.color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(InpensoTheme.body(15, weight: .medium))
                    .foregroundStyle(item.isActive ? InpensoTheme.ink : InpensoTheme.muted)
                    .lineLimit(1)

                Text("\(item.frequency.displayName) · next \(item.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(InpensoTheme.label(12))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: InpensoTheme.Space.xs)

            VStack(alignment: .trailing, spacing: 2) {
                Text(signedAmount)
                    .font(InpensoTheme.displayAmount(15))
                    .foregroundStyle(item.type == .income ? InpensoTheme.incomeTint : InpensoTheme.ink)

                if !item.isActive {
                    Text("Paused")
                        .font(InpensoTheme.label(10, weight: .semibold))
                        .foregroundStyle(InpensoTheme.expenseTint)
                }
            }
        }
        .contentShape(Rectangle())
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
            List {
                Section {
                    TextField("Title", text: $title)

                    HStack(spacing: InpensoTheme.Space.xs) {
                        Text(currencySymbol)
                            .font(InpensoTheme.body(16, weight: .medium))
                            .foregroundStyle(InpensoTheme.muted)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }

                    TransactionTypePicker(type: $type)
                        .listRowInsets(EdgeInsets(
                            top: InpensoTheme.Space.sm,
                            leading: InpensoTheme.Space.screen,
                            bottom: InpensoTheme.Space.sm,
                            trailing: InpensoTheme.Space.screen
                        ))
                } header: {
                    editorHeader("Details")
                }

                Section {
                    Picker("Repeats", selection: $frequency) {
                        ForEach(RecurrenceFrequency.selectableCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    Toggle("End date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Ends", selection: $endDate, displayedComponents: .date)
                    }
                } header: {
                    editorHeader("Schedule")
                }

                Section {
                    Picker("Category", selection: $categoryID) {
                        ForEach(categoryStore.allCategories) { category in
                            Text(category.displayName).tag(category.id)
                        }
                    }
                } header: {
                    editorHeader("Category")
                }

                Section {
                    TextField("Optional", text: $notes)
                } header: {
                    editorHeader("Notes")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AtmosphereBackground())
            .listRowBackground(InpensoTheme.panelFill)
            .listRowSeparatorTint(InpensoTheme.hairline)
            .navigationTitle(existing == nil ? "New recurring" : "Edit recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(InpensoTheme.ink)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(InpensoTheme.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .font(InpensoTheme.label(15, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
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

    private func editorHeader(_ title: String) -> some View {
        Text(title)
            .font(InpensoTheme.sectionLabel())
            .foregroundStyle(InpensoTheme.muted)
            .textCase(nil)
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
