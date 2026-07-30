//
//  OnboardingView.swift
//  iExpense
//
//  First-launch: features → currency → money → cash → account or guest.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: OnboardingStore
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject private var auth = AuthSession.shared

    @State private var step = 0
    @State private var incomeText = ""
    @State private var savingsText = ""
    @State private var budgetText = ""
    @State private var walletText = ""
    @State private var checkingText = ""
    @State private var selectedCurrency: String
    @State private var showAuth = false

    private let featurePages: [(icon: String, title: String, body: String)] = [
        ("chart.line.uptrend.xyaxis", "Know what’s left today", "Available Today turns income, savings, cash on hand, and spend into a daily number you can trust."),
        ("bolt.fill", "Log money in seconds", "Quick Add, receipts, and natural language like “Coffee 4.50” keep your ledger current."),
        ("person.3.fill", "Split trips fairly", "Create a trip, share a code, and settle balances — friends join after you approve."),
        ("icloud.and.arrow.up", "Backup with an account", "Sign in to sync your ledger to \(AppBrand.name) servers. Guest mode stays on this device only.")
    ]

    init(store: OnboardingStore, settings: SettingsViewModel) {
        self.store = store
        self.settings = settings
        _selectedCurrency = State(initialValue: settings.selectedCurrency)
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            VStack(spacing: 0) {
                TabView(selection: $step) {
                    ForEach(Array(featurePages.enumerated()), id: \.offset) { index, page in
                        featurePage(page).tag(index)
                    }
                    currencyPage.tag(featurePages.count)
                    moneyPage.tag(featurePages.count + 1)
                    cashPage.tag(featurePages.count + 2)
                    accountPage.tag(featurePages.count + 3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(InpensoTheme.Motion.snappy, value: step)

                bottomBar
            }
        }
        .sheet(isPresented: $showAuth) {
            AccountAuthView(
                onSuccess: { finish(guest: false) },
                showsGuestHint: true,
                initialMode: .register
            )
        }
    }

    private var lastStep: Int { featurePages.count + 3 }

    private func featurePage(_ page: (icon: String, title: String, body: String)) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.lg) {
            Spacer()
            Text(AppBrand.name)
                .font(InpensoTheme.brandFont(18, weight: .heavy))
                .foregroundStyle(InpensoTheme.tide)

            Image(systemName: page.icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
                .frame(width: 64, height: 64)
                .background(InpensoTheme.tideSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(page.title)
                .font(InpensoTheme.brandFont(32, weight: .bold))
                .foregroundStyle(InpensoTheme.ink)

            Text(page.body)
                .font(InpensoTheme.body(16))
                .foregroundStyle(InpensoTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(InpensoTheme.Space.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currencyPage: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            Text(AppBrand.name)
                .font(InpensoTheme.brandFont(18, weight: .heavy))
                .foregroundStyle(InpensoTheme.tide)

            Text("Home currency")
                .font(InpensoTheme.brandFont(28, weight: .bold))
                .foregroundStyle(InpensoTheme.ink)
            Text("Totals and Available Today use this currency. Trips can still use their own.")
                .font(InpensoTheme.body(15))
                .foregroundStyle(InpensoTheme.muted)

            Picker("Currency", selection: $selectedCurrency) {
                ForEach(availableCurrencies, id: \.code) { currency in
                    Text("\(currency.code) (\(currency.symbol))").tag(currency.code)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 160)

            Spacer()
        }
        .padding(InpensoTheme.Space.screen)
    }

    private var moneyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                Text(AppBrand.name)
                    .font(InpensoTheme.brandFont(18, weight: .heavy))
                    .foregroundStyle(InpensoTheme.tide)

                Text("Your monthly picture")
                    .font(InpensoTheme.brandFont(28, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                Text("Rough numbers are fine — change them later anytime.")
                    .font(InpensoTheme.body(15))
                    .foregroundStyle(InpensoTheme.muted)

                field(title: "Monthly income", text: $incomeText, placeholder: "0")
                field(title: "Monthly savings goal", text: $savingsText, placeholder: "0")
                field(title: "Monthly spend budget", text: $budgetText, placeholder: "Optional")
            }
            .padding(InpensoTheme.Space.screen)
        }
    }

    private var cashPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                Text(AppBrand.name)
                    .font(InpensoTheme.brandFont(18, weight: .heavy))
                    .foregroundStyle(InpensoTheme.tide)

                Text("Cash on hand")
                    .font(InpensoTheme.brandFont(28, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                Text("Available Today never exceeds what you actually have in Wallet and checking. Leave blank if you’re starting at zero.")
                    .font(InpensoTheme.body(15))
                    .foregroundStyle(InpensoTheme.muted)

                field(title: "Wallet", text: $walletText, placeholder: "0")
                field(title: "Main checking", text: $checkingText, placeholder: "0")

                Text("You can add more accounts later in More → Accounts.")
                    .font(InpensoTheme.body(13))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(InpensoTheme.Space.screen)
        }
    }

    /// Same visual language as feature pages: brand, icon, title, body, then actions.
    private var accountPage: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.lg) {
            Spacer(minLength: 12)

            Text(AppBrand.name)
                .font(InpensoTheme.brandFont(18, weight: .heavy))
                .foregroundStyle(InpensoTheme.tide)

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
                .frame(width: 64, height: 64)
                .background(InpensoTheme.tideSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("Save your data")
                .font(InpensoTheme.brandFont(32, weight: .bold))
                .foregroundStyle(InpensoTheme.ink)

            Text("Create an account to back up your ledger and use Trips. Or continue as a guest — nothing is synced and everything can be lost if you delete the app.")
                .font(InpensoTheme.body(16))
                .foregroundStyle(InpensoTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button {
                    showAuth = true
                } label: {
                    Text("Sign in or create account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InpensoPrimaryButtonStyle())

                Button {
                    finish(guest: true)
                } label: {
                    Text("Continue without an account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InpensoSecondaryButtonStyle())
            }

            Text("Guest mode: no data is saved to our servers. Trips stay locked until you sign in.")
                .font(InpensoTheme.body(13))
                .foregroundStyle(InpensoTheme.muted)

            Spacer(minLength: 12)
        }
        .padding(InpensoTheme.Space.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottomBar: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            if step > 0 && step < lastStep {
                Button("Back") {
                    withAnimation { step -= 1 }
                }
                .buttonStyle(InpensoSecondaryButtonStyle())
            }

            if step < lastStep {
                Button("Continue") {
                    withAnimation { step += 1 }
                }
                .buttonStyle(InpensoPrimaryButtonStyle())
            }
        }
        .padding(InpensoTheme.Space.screen)
        .background(InpensoTheme.foam.opacity(0.95))
    }

    private func field(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(InpensoTheme.label(13))
                .foregroundStyle(InpensoTheme.muted)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(InpensoTheme.displayAmount(22))
                .padding(InpensoTheme.Space.md)
                .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
        }
    }

    private func finish(guest: Bool) {
        let income = Double(incomeText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let savings = Double(savingsText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let budget = Double(budgetText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let wallet = Double(walletText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let checking = Double(checkingText.replacingOccurrences(of: ",", with: ".")) ?? 0

        settings.selectedCurrency = selectedCurrency
        if guest {
            auth.continueAsGuest()
        }

        applyCashBalances(wallet: max(0, wallet), checking: max(0, checking))

        store.complete(
            currencyCode: selectedCurrency,
            monthlyIncome: income,
            monthlySavingsTarget: savings,
            monthlyBudget: budget
        )
        if auth.isLoggedIn {
            Task { await CloudSyncService.shared.pushAll() }
        }
    }

    private func applyCashBalances(wallet: Double, checking: Double) {
        let store = PremiumDataStore.shared
        var accounts = store.accounts

        if let idx = accounts.firstIndex(where: { $0.kind == .cash && $0.name.localizedCaseInsensitiveContains("wallet") }) {
            accounts[idx].balance = wallet
        } else if let idx = accounts.firstIndex(where: { $0.kind == .cash }) {
            accounts[idx].balance = wallet
        } else {
            accounts.insert(FinanceAccount(name: "Wallet", kind: .cash, balance: wallet), at: 0)
        }

        if let idx = accounts.firstIndex(where: { $0.kind == .checking }) {
            accounts[idx].balance = checking
        } else {
            accounts.append(FinanceAccount(name: "Main checking", kind: .checking, balance: checking))
        }

        store.replaceAccounts(accounts)
    }
}
