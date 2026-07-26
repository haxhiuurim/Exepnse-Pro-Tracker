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
    @ObservedObject private var pro = ProEntitlementManager.shared
    @State private var selectedTab = 0
    @State private var showQuickAdd = false
    @State private var quickAddType: TransactionType = .expense
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(
                    viewModel: viewModel,
                    analyticsViewModel: analyticsViewModel,
                    showQuickAdd: $showQuickAdd,
                    onAddTransaction: { type in
                        openQuickAdd(type)
                    }
                )
                .tabItem {
                    Label("Money", systemImage: "house.fill")
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
                        .padding(.bottom, 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(viewModel: viewModel, initialType: quickAddType)
            }
            .sheet(isPresented: $pro.showPaywall) {
                PaywallView(pro: pro, initialPlan: pro.selectedPaywallPlan)
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $pro.showSpecialOffer) {
                SpecialOfferPaywallView(pro: pro)
                    .presentationBackground(.clear)
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
            if PremiumDataStore.shared.iCloudSyncEnabled {
                ICloudSyncService.shared.pullIfAvailable()
            }
            Task { await pro.refresh() }

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
                openQuickAdd(.expense)
            }

            NotificationCenter.default.addObserver(
                forName: .inpensoICloudDidPull,
                object: nil,
                queue: .main
            ) { _ in
                viewModel.loadExpenses()
                analyticsViewModel.updateExpenses(viewModel.expenses)
            }
        }
        .onChange(of: viewModel.expenses) {
            analyticsViewModel.updateExpenses(viewModel.expenses)
            if pro.isPro {
                SpentTodayLiveActivity.startOrUpdate(
                    amount: viewModel.spent(for: .today),
                    currencyCode: settingsViewModel.selectedCurrency,
                    isPro: true
                )
                if PremiumDataStore.shared.iCloudSyncEnabled {
                    ICloudSyncService.shared.pushAll()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.loadExpenses()
                processRecurring()
                consumePendingQuickAdd()
                if PremiumDataStore.shared.iCloudSyncEnabled {
                    ICloudSyncService.shared.pullIfAvailable()
                }
            case .inactive, .background:
                biometricLock.lockIfNeeded()
            @unknown default:
                break
            }
        }
        .environmentObject(ReminderService.shared)
        .environmentObject(biometricLock)
        .environmentObject(viewModel)
        .environmentObject(pro)
        .environmentObject(PremiumDataStore.shared)
    }

    private func openQuickAdd(_ type: TransactionType) {
        quickAddType = type
        showQuickAdd = true
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
                openQuickAdd(.expense)
            }
        }
    }

    private var floatingAddButton: some View {
        Menu {
            Button {
                openQuickAdd(.expense)
            } label: {
                Label("Add expense", systemImage: "minus.circle")
            }
            Button {
                openQuickAdd(.income)
            } label: {
                Label("Add income", systemImage: "plus.circle")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .fill(InpensoTheme.copper)
                )
        }
        .accessibilityLabel("Add transaction")
        .padding(.bottom, 52)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(InpensoTheme.foam)
        appearance.shadowColor = UIColor(InpensoTheme.hairline)

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(InpensoTheme.muted)
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(InpensoTheme.ink)
        ]

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(InpensoTheme.muted)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(InpensoTheme.ink)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes

        appearance.inlineLayoutAppearance.normal.iconColor = UIColor(InpensoTheme.muted)
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.inlineLayoutAppearance.selected.iconColor = UIColor(InpensoTheme.ink)
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes

        appearance.compactInlineLayoutAppearance.normal.iconColor = UIColor(InpensoTheme.muted)
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.compactInlineLayoutAppearance.selected.iconColor = UIColor(InpensoTheme.ink)
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(InpensoTheme.ink)
        UITabBar.appearance().unselectedItemTintColor = UIColor(InpensoTheme.muted)
    }
}

#Preview {
    MainTabView()
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
