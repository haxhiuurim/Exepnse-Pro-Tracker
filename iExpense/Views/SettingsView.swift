//
//  SettingsView.swift
//  iExpense
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var reminderService: ReminderService
    @EnvironmentObject private var biometricLock: BiometricLockService
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel

    @State private var showingImportFilePicker = false
    @State private var showingExportShareSheet = false
    @State private var exportURL: URL? = nil
    @State private var showingResetConfirmation = false
    @State private var showingImportSuccess = false
    @State private var showingImportFailure = false
    @State private var showingExportSuccess = false
    @State private var biometricError: String?

    var body: some View {
        NavigationStack {
            Form {
                brandHeader
                appearanceSection
                securitySection
                remindersSection
                moneyToolsSection
                currencySection
                defaultSettingsSection
                categoriesSection
                dataManagementSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(AtmosphereBackground(intensity: 0.5))
            .navigationTitle("Settings")
            .tint(InpensoTheme.ink)
            .sheet(isPresented: $showingImportFilePicker) {
                documentPicker
            }
            .sheet(isPresented: $showingExportShareSheet) {
                shareSheet
            }
            .alert("Data Reset", isPresented: $showingResetConfirmation) {
                resetAlertButtons
            } message: {
                Text("This will delete all your expenses, budgets, and recurring items. This action cannot be undone.")
            }
            .alert("Import Successful", isPresented: $showingImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your data has been imported successfully.")
            }
            .alert("Import Failed", isPresented: $showingImportFailure) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Failed to import data. Please check the file format and try again.")
            }
            .alert("Export Successful", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your data has been exported successfully.")
            }
            .alert("Couldn't enable lock", isPresented: Binding(
                get: { biometricError != nil },
                set: { if !$0 { biometricError = nil } }
            )) {
                Button("OK", role: .cancel) { biometricError = nil }
            } message: {
                Text(biometricError ?? "")
            }
        }
    }

    // MARK: - Sections

    private var brandHeader: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Inpenso")
                    .font(InpensoTheme.brandFont(28, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                Text("Tide Ledger · private on-device finance")
                    .font(InpensoTheme.body(13))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)
        }
    }

    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            themePicker
        }
    }

    private var securitySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { biometricLock.isEnabled },
                set: { newValue in
                    Task {
                        if newValue {
                            let ok = await biometricLock.enableAfterAuth()
                            if !ok {
                                biometricError = biometricLock.lastErrorMessage
                                    ?? "Authenticate with \(biometricLock.biometryLabel) to enable the lock."
                            }
                        } else {
                            biometricLock.isEnabled = false
                        }
                    }
                }
            )) {
                Label("Require \(biometricLock.biometryLabel)", systemImage: biometricLock.biometrySymbol)
            }
            .disabled(!biometricLock.canUseBiometrics && !biometricLock.isEnabled)
        } header: {
            Text("Security")
        } footer: {
            Text(
                biometricLock.canUseBiometrics
                ? "When enabled, Inpenso asks for \(biometricLock.biometryLabel) every time you open or return to the app."
                : "Biometrics aren’t available on this device. You can still use the app without a lock."
            )
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("Spending reminders", isOn: $reminderService.isEnabled)

            if reminderService.isEnabled {
                Picker("How often", selection: $reminderService.frequency) {
                    ForEach(ReminderFrequency.allCases) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }

                DatePicker(
                    "Remind me at",
                    selection: Binding(
                        get: { reminderService.reminderDate },
                        set: { reminderService.setReminderTime(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )

                if reminderService.frequency == .weekly {
                    Picker("On", selection: $reminderService.weeklyWeekday) {
                        ForEach(1...7, id: \.self) { weekday in
                            Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
                        }
                    }
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text(
                reminderService.isEnabled
                ? reminderService.frequency.footerHint
                : "Get nudged to log spending on a schedule you choose."
            )
        }
    }

    private var moneyToolsSection: some View {
        Section(header: Text("Money tools")) {
            NavigationLink {
                RecurringTransactionsView(expenseViewModel: expenseViewModel)
            } label: {
                Label("Recurring transactions", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    private var themePicker: some View {
        Picker("Theme", selection: $settingsManager.selectedTheme) {
            ForEach(AppTheme.allCases) { theme in
                Text(theme.displayName).tag(theme)
            }
        }
        .pickerStyle(.menu)
    }

    private var currencySection: some View {
        Section(header: Text("Currency")) {
            currencyPicker
        }
    }

    private var currencyPicker: some View {
        Picker("Currency", selection: $settingsManager.selectedCurrency) {
            ForEach(availableCurrencies, id: \.code) { currency in
                currencyRow(for: currency)
            }
        }
        .pickerStyle(.menu)
    }

    private func currencyRow(for currency: (code: String, symbol: String, name: String)) -> some View {
        Text("\(currency.symbol) \(currency.name) (\(currency.code))")
            .tag(currency.code)
    }

    private var defaultSettingsSection: some View {
        Section(header: Text("Default Settings")) {
            categoryPicker
        }
    }

    private var categoryPicker: some View {
        Picker("Default Category", selection: $settingsManager.defaultCategoryID) {
            ForEach(categoryStore.allCategories) { category in
                categoryRow(for: category)
            }
        }
        .pickerStyle(.menu)
        .onAppear {
            normalizeDefaultCategory()
        }
        .onChange(of: categoryStore.allCategories.map(\.id)) { _, _ in
            normalizeDefaultCategory()
        }
    }

    private func categoryRow(for category: FinanceCategory) -> some View {
        HStack {
            Circle()
                .fill(category.color)
                .frame(width: 12, height: 12)
            Text(category.displayName)
        }
        .tag(category.id)
    }

    private func normalizeDefaultCategory() {
        let preferredCategoryID = categoryStore.preferredCategoryID(for: settingsManager.defaultCategoryID)
        if preferredCategoryID != settingsManager.defaultCategoryID {
            settingsManager.defaultCategoryID = preferredCategoryID
        }
    }

    private var categoriesSection: some View {
        Section(header: Text("Categories")) {
            NavigationLink {
                CategoryManagementView()
            } label: {
                Label("Manage Categories", systemImage: "square.grid.2x2")
            }
        }
    }

    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            exportButton
            importButton
            resetButton
        }
    }

    private var exportButton: some View {
        Button(action: exportData) {
            Label("Export Data", systemImage: "square.and.arrow.up")
        }
    }

    private var importButton: some View {
        Button(action: { showingImportFilePicker = true }) {
            Label("Import Data", systemImage: "square.and.arrow.down")
        }
    }

    private var resetButton: some View {
        Button(role: .destructive, action: { showingResetConfirmation = true }) {
            Label("Reset All Data", systemImage: "trash")
        }
        .foregroundColor(.red)
    }

    private var aboutSection: some View {
        Section(header: Text("About")) {
            versionRow
            HStack {
                Text("Theme")
                Spacer()
                Text("Tide Ledger")
                    .foregroundStyle(InpensoTheme.muted)
            }
        }
    }

    private var versionRow: some View {
        HStack {
            Text("Version")
            Spacer()
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                .foregroundColor(.secondary)
        }
    }

    private var documentPicker: some View {
        DocumentPicker(
            types: [UTType.json],
            allowsMultipleSelection: false
        ) { urls in
            guard let url = urls.first else { return }
            let success = settingsManager.importData(from: url)
            if success {
                showingImportSuccess = true
            } else {
                showingImportFailure = true
            }
        }
    }

    private var shareSheet: some View {
        Group {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var resetAlertButtons: some View {
        Group {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settingsManager.resetAllData()
                expenseViewModel.loadExpenses()
                RecurringTransactionService.shared.reload()
            }
        }
    }

    private func exportData() {
        if let url = settingsManager.exportData() {
            exportURL = url
            showingExportShareSheet = true
            showingExportSuccess = true
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
        .environmentObject(ReminderService.shared)
        .environmentObject(BiometricLockService.shared)
        .environmentObject(ExpenseViewModel())
}
