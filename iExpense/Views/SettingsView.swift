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
    @EnvironmentObject private var pro: ProEntitlementManager
    @ObservedObject private var premiumStore = PremiumDataStore.shared

    @State private var showingImportFilePicker = false
    @State private var showingExportShareSheet = false
    @State private var exportURL: URL? = nil
    @State private var showingResetConfirmation = false
    @State private var showingImportSuccess = false
    @State private var showingImportFailure = false
    @State private var showingExportSuccess = false
    @State private var biometricError: String?
    @State private var exportFormat: ExportFormat = .csv

    private enum ExportFormat { case csv, ofx, pdf }

    private var settingsRowInsets: EdgeInsets {
        EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    }

    var body: some View {
        List {
            appHeader
            proSection
            appearanceSection
            securitySection
            remindersSection
            currencySection
            defaultSettingsSection
            dataManagementSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AtmosphereBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(InpensoTheme.ink)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .listRowBackground(InpensoTheme.panelFill)
        .listRowInsets(settingsRowInsets)
        .listRowSeparatorTint(InpensoTheme.hairline)
        .listSectionSpacing(InpensoTheme.Space.lg)
        .contentMargins(.horizontal, InpensoTheme.Space.screen, for: .scrollContent)
        .contentMargins(.vertical, InpensoTheme.Space.md, for: .scrollContent)
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

    // MARK: - Sections

    private var appHeader: some View {
        Section {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.xxs) {
                Text(AppBrand.name)
                    .font(InpensoTheme.brandFont(24, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                Text(AppBrand.tagline)
                    .font(InpensoTheme.body(13))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(.vertical, InpensoTheme.Space.xs)
            .listRowBackground(Color.clear)
        }
    }

    private var proSection: some View {
        Section {
            if pro.isPro {
                HStack {
                    Label(AppBrand.proName, systemImage: "checkmark.seal")
                        .foregroundStyle(InpensoTheme.ink)
                    Spacer()
                    Text("Active")
                        .font(InpensoTheme.label(12, weight: .semibold))
                        .foregroundStyle(InpensoTheme.incomeTint)
                }
                #if DEBUG
                Button("Debug: remove Pro") { pro.debugTogglePro() }
                    .foregroundStyle(InpensoTheme.danger)
                #endif
            } else {
                Button {
                    pro.openPaywall(plan: .yearly)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: InpensoTheme.Space.xxs) {
                            Text("Upgrade to Pro")
                                .font(InpensoTheme.body(16, weight: .semibold))
                                .foregroundStyle(InpensoTheme.ink)
                            Text("Yearly \(ProPlan.yearly.displayPrice) · Monthly \(ProPlan.monthly.displayPrice)")
                                .font(InpensoTheme.label(12))
                                .foregroundStyle(InpensoTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(InpensoTheme.muted)
                    }
                }
            }

            Toggle("iCloud sync", isOn: Binding(
                get: { premiumStore.iCloudSyncEnabled },
                set: { enabled in
                    if !premiumStore.setiCloudSync(enabled, isPro: pro.isPro) {
                        pro.openPaywall()
                    } else if enabled {
                        ICloudSyncService.shared.pushAll()
                    }
                }
            ))
        } header: {
            sectionHeader("Pro")
        } footer: {
            Text(pro.isPro
                 ? "All Pro features are enabled."
                 : "Pro adds OCR, sync, goals, exports, and unlimited recurring items.")
                .font(InpensoTheme.body(12))
                .foregroundStyle(InpensoTheme.muted)
        }
    }

    private var appearanceSection: some View {
        Section {
            themePicker
        } header: {
            sectionHeader("Appearance")
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
            sectionHeader("Security")
        } footer: {
            Text(
                biometricLock.canUseBiometrics
                ? "Requires \(biometricLock.biometryLabel) when opening or returning to the app."
                : "Biometrics are not available on this device."
            )
            .font(InpensoTheme.body(12))
            .foregroundStyle(InpensoTheme.muted)
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
            sectionHeader("Reminders")
        } footer: {
            Text(
                reminderService.isEnabled
                ? reminderService.frequency.footerHint
                : "Schedule reminders to log spending."
            )
            .font(InpensoTheme.body(12))
            .foregroundStyle(InpensoTheme.muted)
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
        Section {
            currencyPicker
        } header: {
            sectionHeader("Currency")
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
        Section {
            categoryPicker
        } header: {
            sectionHeader("Defaults")
        }
    }

    private var categoryPicker: some View {
        Picker("Default category", selection: $settingsManager.defaultCategoryID) {
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
                .frame(width: 10, height: 10)
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

    private var dataManagementSection: some View {
        Section {
            exportButton
            Button {
                guard pro.isPro else { pro.openPaywall(); return }
                exportFormat = .csv
                exportProData(format: .csv)
            } label: {
                Label("Export CSV (Pro)", systemImage: "tablecells")
            }
            Button {
                guard pro.isPro else { pro.openPaywall(); return }
                exportFormat = .ofx
                exportProData(format: .ofx)
            } label: {
                Label("Export OFX (Pro)", systemImage: "doc.badge.gearshape")
            }
            Button {
                guard pro.isPro else { pro.openPaywall(); return }
                exportFormat = .pdf
                exportProData(format: .pdf)
            } label: {
                Label("Export PDF (Pro)", systemImage: "doc.richtext")
            }
            importButton
            resetButton
        } header: {
            sectionHeader("Data")
        }
        footer: {
            Text("Personal ledger stays on device. Optional Pro iCloud sync backs up your data. Shared Trips use a server only when you create or join a trip.")
                .font(InpensoTheme.label(11))
        }
    }

    private func exportProData(format: ExportFormat) {
        let url: URL?
        switch format {
        case .csv:
            url = ExportService.csvURL(expenses: expenseViewModel.expenses, currencyCode: settingsManager.selectedCurrency)
        case .ofx:
            url = ExportService.ofxURL(expenses: expenseViewModel.expenses, currencyCode: settingsManager.selectedCurrency)
        case .pdf:
            url = ExportService.pdfURL(expenses: expenseViewModel.expenses, currencyCode: settingsManager.selectedCurrency)
        }
        if let url {
            exportURL = url
            showingExportShareSheet = true
            showingExportSuccess = true
        }
    }

    private var exportButton: some View {
        Button(action: exportData) {
            Label("Export data", systemImage: "square.and.arrow.up")
        }
    }

    private var importButton: some View {
        Button(action: { showingImportFilePicker = true }) {
            Label("Import data", systemImage: "square.and.arrow.down")
        }
    }

    private var resetButton: some View {
        Button(role: .destructive, action: { showingResetConfirmation = true }) {
            Label("Reset all data", systemImage: "trash")
        }
        .foregroundStyle(InpensoTheme.danger)
    }

    private var aboutSection: some View {
        Section {
            versionRow
            HStack {
                Text("Build")
                    .foregroundStyle(InpensoTheme.ink)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    .foregroundStyle(InpensoTheme.muted)
            }
            HStack {
                Text("Stability")
                    .foregroundStyle(InpensoTheme.ink)
                Spacer()
                if let date = CrashReportingService.lastCrashDate {
                    Text("Last crash \(date.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(InpensoTheme.danger)
                } else {
                    Text("Crash-free")
                        .foregroundStyle(InpensoTheme.incomeTint)
                }
            }
            #if DEBUG
            if CrashReportingService.lastCrashFingerprint != nil {
                Button("Clear crash record") {
                    CrashReportingService.clearCrashRecord()
                }
            }
            #endif
        } header: {
            sectionHeader("About")
        } footer: {
            Text("Release gate: ship only when Stability shows Crash-free. Run scripts/stability_gate.sh before App Store builds.")
                .font(InpensoTheme.label(11))
        }
    }

    private var versionRow: some View {
        HStack {
            Text("Version")
                .foregroundStyle(InpensoTheme.ink)
            Spacer()
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                .foregroundStyle(InpensoTheme.muted)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(InpensoTheme.sectionLabel())
            .foregroundStyle(InpensoTheme.muted)
            .textCase(nil)
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
        .environmentObject(ProEntitlementManager.shared)
}
