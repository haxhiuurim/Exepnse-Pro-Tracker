//
//  MainTabView.swift
//  iExpense
//
//  Tab IA: Home · Activity · Trips · More
//

import SwiftUI
import SwiftData

private enum AppTab: Int {
    case home = 0
    case activity = 1
    case trips = 2
    case more = 3
}

struct MainTabView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @StateObject private var analyticsViewModel = AnalyticsViewModel(expenses: [])
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @ObservedObject private var biometricLock = BiometricLockService.shared
    @ObservedObject private var pro = ProEntitlementManager.shared
    @State private var selectedTab = AppTab.home.rawValue
    @State private var showQuickAdd = false
    @State private var quickAddType: TransactionType = .expense
    @Environment(\.scenePhase) private var scenePhase

    private var showsFloatingAdd: Bool { false }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(
                    viewModel: viewModel,
                    analyticsViewModel: analyticsViewModel,
                    showQuickAdd: $showQuickAdd,
                    onAddTransaction: { openQuickAdd($0) }
                )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home.rawValue)

                ExpensesListView(viewModel: viewModel)
                    .tabItem {
                        Label("Activity", systemImage: "list.bullet")
                    }
                    .tag(AppTab.activity.rawValue)

                NavigationStack {
                    SharedTripsView()
                }
                .tabItem {
                    Label("Trips", systemImage: "person.3.fill")
                }
                .tag(AppTab.trips.rawValue)

                MoreHubView(
                    analyticsViewModel: analyticsViewModel,
                    expenseViewModel: viewModel
                )
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(AppTab.more.rawValue)
            }
            .tint(InpensoTheme.ink)
            .id(settingsViewModel.selectedCurrency)
            .preferredColorScheme(settingsViewModel.selectedTheme.colorScheme)
            .overlay(alignment: .bottom) {
                if showsFloatingAdd && biometricLock.isUnlocked {
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
                selectedTab = AppTab.activity.rawValue
            }

            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SwitchToTripsTab"),
                object: nil,
                queue: .main
            ) { _ in
                selectedTab = AppTab.trips.rawValue
            }

            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenQuickAdd"),
                object: nil,
                queue: .main
            ) { notification in
                let raw = notification.userInfo?["type"] as? String
                let type = raw.flatMap(TransactionType.init(rawValue:)) ?? .expense
                openQuickAdd(type)
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
                    ICloudSyncService.shared.pushAll()
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
            let typeRaw = defaults?.string(forKey: "pendingQuickAddType") ?? TransactionType.expense.rawValue
            defaults?.removeObject(forKey: "pendingQuickAddType")
            defaults?.synchronize()
            let type = TransactionType(rawValue: typeRaw) ?? .expense
            selectedTab = AppTab.home.rawValue
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                openQuickAdd(type)
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
                        .fill(InpensoTheme.tide)
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

        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            layout.normal.iconColor = UIColor(InpensoTheme.muted)
            layout.normal.titleTextAttributes = normalAttributes
            layout.selected.iconColor = UIColor(InpensoTheme.ink)
            layout.selected.titleTextAttributes = selectedAttributes
        }

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
