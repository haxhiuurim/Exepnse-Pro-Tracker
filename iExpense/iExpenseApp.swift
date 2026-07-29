//
//  iExpenseApp.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import Foundation

@main
struct iExpenseApp: App {
    init() {
        CrashReportingService.install()
        syncSettingsToSharedDefaults()
        configureGlobalAppearance()
    }

    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var categoryStore = CategoryStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .withSwiftData()
                .task {
                    await SwiftDataProvider.shared.startMigration()
                }
                .environmentObject(settingsViewModel)
                .environmentObject(categoryStore)
                .preferredColorScheme(settingsViewModel.selectedTheme.colorScheme)
                .tint(InpensoTheme.ink)
        }
    }

    private func syncSettingsToSharedDefaults() {
        let sharedDefaults = UserDefaults(suiteName: StorageService.appGroupID)

        if let currency = UserDefaults.standard.string(forKey: "selectedCurrency") {
            sharedDefaults?.set(currency, forKey: "selectedCurrency")
            sharedDefaults?.synchronize()
        } else {
            let defaultCurrency = "USD"
            UserDefaults.standard.set(defaultCurrency, forKey: "selectedCurrency")
            sharedDefaults?.set(defaultCurrency, forKey: "selectedCurrency")
            sharedDefaults?.synchronize()
        }
    }

    private func configureGlobalAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(InpensoTheme.foam)
        nav.shadowColor = .clear
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(InpensoTheme.ink),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(InpensoTheme.ink),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(InpensoTheme.tide)
    }
}
