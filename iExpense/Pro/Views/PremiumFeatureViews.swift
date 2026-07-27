//
//  PremiumFeatureViews.swift
//  iExpense
//
//  Goals, accounts, merchant rules, household, themes, upcoming calendar.
//

import SwiftUI

// MARK: - Shared list chrome

private struct PremiumListChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .listRowBackground(InpensoTheme.panelFill)
            .listRowSeparatorTint(InpensoTheme.hairline)
            .listSectionSpacing(InpensoTheme.Space.section)
    }
}

private extension View {
    func premiumListChrome() -> some View {
        modifier(PremiumListChrome())
    }
}

// MARK: - Savings goals

struct SavingsGoalsView: View {
    @EnvironmentObject private var pro: ProEntitlementManager
    @EnvironmentObject private var settings: SettingsViewModel
    @ObservedObject private var store = PremiumDataStore.shared
    @State private var editing: SavingsGoal?
    @State private var showEditor = false

    var body: some View {
        ZStack {
            AtmosphereBackground(intensity: 0.5)
            List {
                if !pro.isPro {
                    Section {
                        ProGateBanner(message: "Savings goals & envelopes are a Pro feature.") {
                            pro.openPaywall()
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                Section {
                    if store.goals.isEmpty {
                        Text(pro.isPro ? "Create a goal or envelope to track a target amount." : "Upgrade to start tracking goals.")
                            .font(InpensoTheme.body(14))
                            .foregroundStyle(InpensoTheme.muted)
                    } else {
                        ForEach(store.goals) { goal in
                            Button {
                                guard pro.isPro else { pro.openPaywall(); return }
                                editing = goal
                                showEditor = true
                            } label: {
                                goalRow(goal)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            guard pro.isPro else { return }
                            indexSet.map { store.goals[$0] }.forEach(store.deleteGoal)
                        }
                    }
                }
            }
            .premiumListChrome()
        }
        .navigationTitle("Goals & envelopes")
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard pro.isPro else { pro.openPaywall(); return }
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus").foregroundStyle(InpensoTheme.ink)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            GoalEditorSheet(existing: editing) { store.upsertGoal($0) }
                .environmentObject(settings)
        }
    }

    private func goalRow(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goal.iconName)
                    .foregroundStyle(goal.accent)
                Text(goal.name)
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Spacer()
                Text(goal.isEnvelope ? "Envelope" : "Goal")
                    .font(InpensoTheme.label(11, weight: .medium))
                    .foregroundStyle(InpensoTheme.muted)
            }
            ProgressView(value: goal.progress)
                .tint(goal.accent)
            HStack {
                Text(goal.currentAmount, format: .currency(code: settings.selectedCurrency))
                Spacer()
                Text("of \(goal.targetAmount.formatted(.currency(code: settings.selectedCurrency)))")
                    .foregroundStyle(InpensoTheme.muted)
            }
            .font(InpensoTheme.label(12, weight: .semibold))
        }
        .padding(.vertical, 4)
    }
}

struct GoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel
    let existing: SavingsGoal?
    let onSave: (SavingsGoal) -> Void

    @State private var name = ""
    @State private var target = ""
    @State private var current = ""
    @State private var isEnvelope = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Target", text: $target).keyboardType(.decimalPad)
                TextField("Saved so far", text: $current).keyboardType(.decimalPad)
                Toggle("Envelope (budget bucket)", isOn: $isEnvelope)
            }
            .navigationTitle(existing == nil ? "New goal" : "Edit goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let t = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let c = Double(current.replacingOccurrences(of: ",", with: ".")) ?? 0
                        guard !name.isEmpty, t > 0 else { return }
                        onSave(SavingsGoal(
                            id: existing?.id ?? UUID(),
                            name: name,
                            targetAmount: t,
                            currentAmount: c,
                            accentHex: existing?.accentHex ?? "#059669",
                            iconName: isEnvelope ? "tray.full" : "target",
                            isEnvelope: isEnvelope
                        ))
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    target = String(format: "%.0f", existing.targetAmount)
                    current = String(format: "%.0f", existing.currentAmount)
                    isEnvelope = existing.isEnvelope
                }
            }
        }
    }
}

// MARK: - Accounts

struct AccountsNetWorthView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel
    @ObservedObject private var store = PremiumDataStore.shared
    @State private var editing: FinanceAccount?
    @State private var showEditor = false

    var body: some View {
        ZStack {
            AtmosphereBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accounts")
                            .font(InpensoTheme.brandFont(28, weight: .heavy))
                            .foregroundStyle(InpensoTheme.ink)
                        Text("Cash on hand updates as you spend and earn")
                            .font(InpensoTheme.label(13))
                            .foregroundStyle(InpensoTheme.muted)
                    }

                    summaryHero

                    VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                        InpensoSectionHeader(title: "Your accounts")

                        if store.accounts.isEmpty {
                            emptyAccounts
                        } else {
                            ForEach(store.accounts) { account in
                                NavigationLink {
                                    AccountDetailView(accountID: account.id)
                                } label: {
                                    accountRow(account)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, InpensoTheme.Space.screen)
                .padding(.top, InpensoTheme.Space.sm)
                .padding(.bottom, InpensoTheme.Space.bottomClearance)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            AccountEditorSheet(existing: editing) { account, previous in
                _ = expenseViewModel.recordAccountBalanceChange(account: account, previous: previous)
            }
        }
    }

    private var summaryHero: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Available cash")
                    .font(InpensoTheme.label(13, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
                Text(store.availableCash, format: .currency(code: settings.selectedCurrency))
                    .font(InpensoTheme.displayAmount(36))
                    .foregroundStyle(InpensoTheme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net worth")
                        .font(InpensoTheme.label(11, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)
                        .textCase(.uppercase)
                    Text(store.netWorth, format: .currency(code: settings.selectedCurrency))
                        .font(InpensoTheme.displayAmount(16))
                        .foregroundStyle(store.netWorth >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(InpensoTheme.hairline)
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, InpensoTheme.Space.md)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Accounts")
                        .font(InpensoTheme.label(11, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)
                        .textCase(.uppercase)
                    Text("\(store.accounts.count)")
                        .font(InpensoTheme.displayAmount(16))
                        .foregroundStyle(InpensoTheme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(InpensoTheme.Space.lg)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
    }

    private func accountRow(_ account: FinanceAccount) -> some View {
        HStack(spacing: InpensoTheme.Space.md) {
            Image(systemName: account.kind.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
                .frame(width: 48, height: 48)
                .background(
                    InpensoTheme.tide.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(InpensoTheme.body(16, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                Text(account.kind.displayName)
                    .font(InpensoTheme.label(12))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: 4)

            Text(account.signedBalance, format: .currency(code: settings.selectedCurrency))
                .font(InpensoTheme.displayAmount(16))
                .foregroundStyle(account.kind.countsAsLiability ? InpensoTheme.expenseTint : InpensoTheme.ink)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(InpensoTheme.muted.opacity(0.6))
        }
        .padding(InpensoTheme.Space.md)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
    }

    private var emptyAccounts: some View {
        VStack(spacing: InpensoTheme.Space.md) {
            Image(systemName: "building.columns")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(InpensoTheme.tide.opacity(0.7))
            Text("No accounts yet")
                .font(InpensoTheme.brandFont(20, weight: .bold))
                .foregroundStyle(InpensoTheme.ink)
            Text("Add a wallet or bank balance. Changes are logged as income or expenses.")
                .font(InpensoTheme.body(14))
                .foregroundStyle(InpensoTheme.muted)
                .multilineTextAlignment(.center)
            Button {
                editing = nil
                showEditor = true
            } label: {
                Text("Add account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.tide))
        }
        .padding(InpensoTheme.Space.xl)
        .frame(maxWidth: .infinity)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
    }
}

struct AccountDetailView: View {
    let accountID: UUID

    @EnvironmentObject private var settings: SettingsViewModel
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject private var store = PremiumDataStore.shared
    @State private var showEditor = false

    private var account: FinanceAccount? {
        store.accounts.first { $0.id == accountID }
    }

    private var history: [Expense] {
        expenseViewModel.transactions(forAccountID: accountID)
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()

            if let account {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                        detailHero(account)

                        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                            InpensoSectionHeader(title: "History")

                            if history.isEmpty {
                                Text("No transactions linked to this account yet. Spending and balance edits will show up here.")
                                    .font(InpensoTheme.body(14))
                                    .foregroundStyle(InpensoTheme.muted)
                                    .padding(InpensoTheme.Space.lg)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(history.enumerated()), id: \.element.id) { index, expense in
                                        TransactionRowView(
                                            expense: expense,
                                            currencyCode: settings.selectedCurrency,
                                            category: categoryStore.category(for: expense)
                                        )
                                        .padding(.horizontal, InpensoTheme.Space.md)
                                        .padding(.vertical, InpensoTheme.Space.sm)

                                        if index < history.count - 1 {
                                            Divider().overlay(InpensoTheme.hairline).padding(.leading, 68)
                                        }
                                    }
                                }
                                .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
                            }
                        }
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, InpensoTheme.Space.xxl)
                }
            } else {
                Text("Account not found")
                    .foregroundStyle(InpensoTheme.muted)
            }
        }
        .navigationTitle(account?.name ?? "Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditor = true }
                    .fontWeight(.semibold)
                    .foregroundStyle(InpensoTheme.tide)
                    .disabled(account == nil)
            }
        }
        .sheet(isPresented: $showEditor) {
            if let account {
                AccountEditorSheet(existing: account) { updated, previous in
                    _ = expenseViewModel.recordAccountBalanceChange(account: updated, previous: previous)
                }
            }
        }
    }

    private func detailHero(_ account: FinanceAccount) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            HStack(spacing: InpensoTheme.Space.md) {
                Image(systemName: account.kind.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
                    .frame(width: 52, height: 52)
                    .background(
                        InpensoTheme.tide.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.kind.displayName)
                        .font(InpensoTheme.label(13, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)
                    Text(account.signedBalance, format: .currency(code: settings.selectedCurrency))
                        .font(InpensoTheme.displayAmount(32))
                        .foregroundStyle(account.kind.countsAsLiability ? InpensoTheme.expenseTint : InpensoTheme.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }

            Text(account.includeInNetWorth ? "Included in net worth" : "Hidden from net worth")
                .font(InpensoTheme.label(12))
                .foregroundStyle(InpensoTheme.muted)
        }
        .padding(InpensoTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
    }
}

struct AccountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existing: FinanceAccount?
    let onSave: (_ account: FinanceAccount, _ previous: FinanceAccount?) -> Void

    @State private var name = ""
    @State private var kind: AccountKind = .checking
    @State private var balance = ""
    @State private var include = true
    @FocusState private var balanceFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(existing == nil ? "New account" : "Edit account")
                                .font(InpensoTheme.brandFont(26, weight: .heavy))
                                .foregroundStyle(InpensoTheme.ink)
                            Text("Balance increases are logged as income; decreases as expenses.")
                                .font(InpensoTheme.body(14))
                                .foregroundStyle(InpensoTheme.muted)
                        }

                        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                            fieldLabel("Name")
                            TextField("e.g. Main checking", text: $name)
                                .font(InpensoTheme.body(17, weight: .medium))
                                .padding(InpensoTheme.Space.md)
                                .background(InpensoTheme.mist, in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous))

                            fieldLabel("Type")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: InpensoTheme.Space.sm) {
                                ForEach(AccountKind.allCases) { option in
                                    let selected = kind == option
                                    Button {
                                        kind = option
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: option.iconName)
                                            Text(option.displayName)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .font(InpensoTheme.label(13, weight: .semibold))
                                        .foregroundStyle(selected ? .white : InpensoTheme.ink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                                .fill(selected ? InpensoTheme.ink : InpensoTheme.mist)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            fieldLabel("Balance")
                            TextField("0.00", text: $balance)
                                .font(InpensoTheme.displayAmount(28))
                                .keyboardType(.decimalPad)
                                .focused($balanceFocused)
                                .padding(InpensoTheme.Space.md)
                                .background(InpensoTheme.mist, in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous))

                            Toggle(isOn: $include) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Include in net worth")
                                        .font(InpensoTheme.body(15, weight: .semibold))
                                        .foregroundStyle(InpensoTheme.ink)
                                    Text("Turn off for tracking-only accounts")
                                        .font(InpensoTheme.label(12))
                                        .foregroundStyle(InpensoTheme.muted)
                                }
                            }
                            .tint(InpensoTheme.tide)
                        }
                        .padding(InpensoTheme.Space.lg)
                        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)

                        Button(action: save) {
                            Text("Save account")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.tide))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, InpensoTheme.Space.screen)
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, InpensoTheme.Space.xxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(InpensoTheme.muted)
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    kind = existing.kind
                    balance = String(format: "%.2f", existing.balance)
                    include = existing.includeInNetWorth
                }
                balanceFocused = existing == nil
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(InpensoTheme.label(12, weight: .semibold))
            .foregroundStyle(InpensoTheme.muted)
            .textCase(.uppercase)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let value = Double(balance.replacingOccurrences(of: ",", with: ".")) ?? 0
        let account = FinanceAccount(
            id: existing?.id ?? UUID(),
            name: trimmed,
            kind: kind,
            balance: abs(value),
            includeInNetWorth: include
        )
        onSave(account, existing)
        dismiss()
    }
}

// MARK: - Merchant rules
struct MerchantRulesView: View {
    @EnvironmentObject private var pro: ProEntitlementManager
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject private var store = PremiumDataStore.shared
    @State private var editing: MerchantRule?
    @State private var showEditor = false

    var body: some View {
        ZStack {
            AtmosphereBackground(intensity: 0.5)
            List {
                Section {
                    Text("When a spend title contains a match, \(AppBrand.name) picks the category for you.")
                        .font(InpensoTheme.body(13))
                        .foregroundStyle(InpensoTheme.muted)
                        .listRowBackground(Color.clear)
                }

                if !pro.isPro {
                    Section {
                        ProGateBanner(message: "Merchant rules are part of Pro.") {
                            pro.openPaywall()
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                Section("Rules") {
                    ForEach(store.merchantRules) { rule in
                        Button {
                            guard pro.isPro else { pro.openPaywall(); return }
                            editing = rule
                            showEditor = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.matchText)
                                        .font(InpensoTheme.body(15, weight: .semibold))
                                        .foregroundStyle(InpensoTheme.ink)
                                    Text("→ \(categoryStore.category(for: rule.categoryID).displayName)")
                                        .font(InpensoTheme.label(12))
                                        .foregroundStyle(InpensoTheme.muted)
                                }
                                Spacer()
                                Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(rule.isEnabled ? InpensoTheme.surplus : InpensoTheme.muted)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        guard pro.isPro else { return }
                        offsets.map { store.merchantRules[$0] }.forEach(store.deleteRule)
                    }
                }
            }
            .premiumListChrome()
        }
        .navigationTitle("Merchant rules")
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard pro.isPro else { pro.openPaywall(); return }
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus").foregroundStyle(InpensoTheme.ink)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            MerchantRuleEditor(existing: editing, categories: categoryStore.allCategories) {
                store.upsertRule($0)
            }
        }
    }
}

struct MerchantRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let existing: MerchantRule?
    let categories: [FinanceCategory]
    let onSave: (MerchantRule) -> Void

    @State private var match = ""
    @State private var categoryID = Category.others.categoryID
    @State private var enabled = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Contains text", text: $match)
                Picker("Category", selection: $categoryID) {
                    ForEach(categories) { Text($0.displayName).tag($0.id) }
                }
                Toggle("Enabled", isOn: $enabled)
            }
            .navigationTitle(existing == nil ? "New rule" : "Edit rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !match.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onSave(MerchantRule(
                            id: existing?.id ?? UUID(),
                            matchText: match.trimmingCharacters(in: .whitespaces),
                            categoryID: categoryID,
                            isEnabled: enabled
                        ))
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let existing {
                    match = existing.matchText
                    categoryID = existing.categoryID
                    enabled = existing.isEnabled
                }
            }
        }
    }
}

// MARK: - Household

struct HouseholdLedgerView: View {
    @EnvironmentObject private var pro: ProEntitlementManager
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject private var store = PremiumDataStore.shared
    @State private var memberName = ""
    @State private var showCopied = false

    var body: some View {
        ZStack {
            AtmosphereBackground(intensity: 0.5)
            List {
                if !pro.isPro {
                    Section {
                        ProGateBanner(message: "Shared household ledger is a Pro feature.") {
                            pro.openPaywall()
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                Section("Household") {
                    TextField("Name", text: Binding(
                        get: { store.household.name },
                        set: {
                            store.household.name = $0
                            if pro.isPro { store.saveHousehold() }
                        }
                    ))
                    .disabled(!pro.isPro)

                    HStack {
                        Text("Invite code")
                        Spacer()
                        Text(store.household.inviteCode)
                            .font(InpensoTheme.label(14, weight: .semibold))
                            .foregroundStyle(InpensoTheme.ink)
                        Button {
                            UIPasteboard.general.string = store.household.inviteCode
                            showCopied = true
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .disabled(!pro.isPro)
                    }

                    Button("Regenerate code") {
                        guard pro.isPro else { pro.openPaywall(); return }
                        store.regenerateInviteCode()
                    }
                }

                Section("Members") {
                    ForEach(store.household.members) { member in
                        HStack {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color(hex: member.colorHex) ?? InpensoTheme.tide)
                                .frame(width: 4, height: 16)
                            Text(member.name)
                            if member.isOwner {
                                Text("Owner")
                                    .font(InpensoTheme.label(10, weight: .medium))
                                    .foregroundStyle(InpensoTheme.muted)
                            }
                        }
                    }

                    if pro.isPro {
                        HStack {
                            TextField("Add partner name", text: $memberName)
                            Button("Add") {
                                let trimmed = memberName.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                store.addHouseholdMember(name: trimmed)
                                memberName = ""
                            }
                        }
                    }
                }

                Section("Shared categories") {
                    ForEach(categoryStore.allCategories) { category in
                        Toggle(category.displayName, isOn: Binding(
                            get: { store.household.sharedCategoryIDs.contains(category.id) },
                            set: { on in
                                guard pro.isPro else { pro.openPaywall(); return }
                                if on {
                                    store.household.sharedCategoryIDs.append(category.id)
                                } else {
                                    store.household.sharedCategoryIDs.removeAll { $0 == category.id }
                                }
                                store.saveHousehold()
                            }
                        ))
                    }
                }
            }
            .premiumListChrome()
        }
        .navigationTitle("Household")
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Copied", isPresented: $showCopied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Invite code copied. Share it with your partner.")
        }
    }
}

// MARK: - Themes (removed — single North theme only)

/// Kept as an empty destination for any stale links; app ships one theme.
struct ThemePacksView: View {
    var body: some View {
        ZStack {
            AtmosphereBackground()
            VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                Text("North")
                    .font(InpensoTheme.brandFont(22, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                Text("\(AppBrand.name) uses one visual theme — navy type, cobalt accent, soft blue canvas.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(InpensoTheme.Space.screen)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Upcoming recurring calendar (Pro)

struct UpcomingRecurringCalendarView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @ObservedObject private var recurring = RecurringTransactionService.shared

    private var upcoming: [(Date, RecurringTransaction)] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 31, to: start) else { return [] }

        var result: [(Date, RecurringTransaction)] = []
        for item in recurring.items where item.isActive {
            var cursor = max(item.nextDueDate, start)
            var guardCount = 0
            while cursor <= end && guardCount < 8 {
                if let itemEnd = item.endDate, cursor > itemEnd { break }
                result.append((cursor, item))
                cursor = item.frequency.nextDate(after: cursor)
                guardCount += 1
            }
        }
        return result.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ZStack {
            AtmosphereBackground(intensity: 0.5)
            List {
                Section {
                    Text("Next 30 days of recurring charges and income.")
                        .font(InpensoTheme.body(13))
                        .foregroundStyle(InpensoTheme.muted)
                        .listRowBackground(Color.clear)
                }
                Section("Upcoming") {
                    if upcoming.isEmpty {
                        Text("Nothing due in the next month.")
                            .foregroundStyle(InpensoTheme.muted)
                    } else {
                        ForEach(Array(upcoming.enumerated()), id: \.offset) { _, pair in
                            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: pair.0).day ?? 0
                            let paySoon = daysUntil >= 0 && daysUntil <= 7
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pair.1.title)
                                        .font(InpensoTheme.body(15, weight: .semibold))
                                        .foregroundStyle(InpensoTheme.ink)
                                    if paySoon {
                                        Text("Pay soon")
                                            .font(InpensoTheme.label(10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                InpensoTheme.tide,
                                                in: Capsule()
                                            )
                                    }
                                    Text(pair.0, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                        .font(InpensoTheme.label(12))
                                        .foregroundStyle(InpensoTheme.muted)
                                }
                                Spacer()
                                Text(pair.1.amount, format: .currency(code: settings.selectedCurrency))
                                    .foregroundStyle(pair.1.type == .income ? InpensoTheme.surplus : InpensoTheme.ink)
                            }
                        }
                    }
                }
            }
            .premiumListChrome()
        }
        .navigationTitle("This month")
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
