//
//  MainTabView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @StateObject private var analyticsViewModel = AnalyticsViewModel(expenses: [])
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @ObservedObject private var biometricLock = BiometricLockService.shared
    @State private var selectedTab = 0
    @State private var showQuickAdd = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(
                    viewModel: viewModel,
                    analyticsViewModel: analyticsViewModel,
                    showQuickAdd: $showQuickAdd
                )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

                AnalyticsView(analyticsViewModel: analyticsViewModel)
                    .tabItem {
                        Label("Insights", systemImage: "chart.xyaxis.line")
                    }
                    .tag(1)

                ExpensesListView(viewModel: viewModel)
                    .tabItem {
                        Label("Activity", systemImage: "list.bullet")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(3)
            }
            .tint(InpensoTheme.ink)
            .id(settingsViewModel.selectedCurrency)
            .preferredColorScheme(settingsViewModel.selectedTheme.colorScheme)
            .overlay(alignment: .bottom) {
                if selectedTab != 3 && biometricLock.isUnlocked {
                    floatingAddButton
                        .padding(.bottom, 56)
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(viewModel: viewModel)
            }
            .disabled(biometricLock.isEnabled && !biometricLock.isUnlocked)

            if biometricLock.isEnabled && !biometricLock.isUnlocked {
                AppLockView(lockService: biometricLock)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: biometricLock.isUnlocked)
        .onAppear {
            analyticsViewModel.updateExpenses(viewModel.expenses)
            configureTabBarAppearance()
            consumePendingQuickAdd()
            processRecurring()
            if biometricLock.isEnabled {
                biometricLock.lockIfNeeded()
            }

            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SwitchToExpensesTab"),
                object: nil,
                queue: .main
            ) { _ in
                selectedTab = 2
            }

            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenQuickAdd"),
                object: nil,
                queue: .main
            ) { _ in
                showQuickAdd = true
            }
        }
        .onChange(of: viewModel.expenses) {
            analyticsViewModel.updateExpenses(viewModel.expenses)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.loadExpenses()
                processRecurring()
                consumePendingQuickAdd()
            case .inactive, .background:
                biometricLock.lockIfNeeded()
            @unknown default:
                break
            }
        }
        .environmentObject(ReminderService.shared)
        .environmentObject(biometricLock)
        .environmentObject(viewModel)
    }

    private func processRecurring() {
        let created = RecurringTransactionService.shared.processDueTransactions(into: viewModel)
        if !created.isEmpty {
            analyticsViewModel.updateExpenses(viewModel.expenses)
        }
    }

    private func consumePendingQuickAdd() {
        let defaults = UserDefaults(suiteName: StorageService.appGroupID)
        if defaults?.bool(forKey: "pendingQuickAdd") == true {
            defaults?.set(false, forKey: "pendingQuickAdd")
            defaults?.synchronize()
            selectedTab = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showQuickAdd = true
            }
        }
    }

    private var floatingAddButton: some View {
        Button {
            HapticFeedback.impact(style: .medium)
            showQuickAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [InpensoTheme.copper, InpensoTheme.copperSoft],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: InpensoTheme.copper.opacity(0.4), radius: 12, x: 0, y: 6)
                )
        }
        .accessibilityLabel("Add spend")
        .offset(y: -6)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(InpensoTheme.foam)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    MainTabView()
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
