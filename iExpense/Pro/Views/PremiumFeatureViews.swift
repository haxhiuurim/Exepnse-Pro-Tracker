//
//  PremiumFeatureViews.swift
//  iExpense
//
//  Goals, accounts, merchant rules, household, themes, upcoming calendar.
//

import SwiftUI

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
                        Text(pro.isPro ? "Create a goal or envelope to give money a job." : "Upgrade to start tracking goals.")
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
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Goals & envelopes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard pro.isPro else { pro.openPaywall(); return }
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus").foregroundStyle(InpensoTheme.copper)
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
                    .font(InpensoTheme.label(11, weight: .bold))
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
                            accentHex: existing?.accentHex ?? "#2A8F87",
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
    @EnvironmentObject private var pro: ProEntitlementManager
    @EnvironmentObject private var settings: SettingsViewModel
    @ObservedObject private var store = PremiumDataStore.shared
    @State private var editing: FinanceAccount?
    @State private var showEditor = false

    var body: some View {
        ZStack {
            AtmosphereBackground(intensity: 0.5)
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Net worth")
                            .font(InpensoTheme.label(12, weight: .bold))
                            .foregroundStyle(InpensoTheme.muted)
                        Text(store.netWorth, format: .currency(code: settings.selectedCurrency))
                            .font(InpensoTheme.displayAmount(32))
                            .foregroundStyle(store.netWorth >= 0 ? InpensoTheme.ink : InpensoTheme.danger)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.white.opacity(0.65))
                }

                if !pro.isPro {
                    Section {
                        ProGateBanner(message: "Accounts & net worth unlock with Pro.") {
                            pro.openPaywall()
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                Section("Accounts") {
                    ForEach(store.accounts) { account in
                        Button {
                            guard pro.isPro else { pro.openPaywall(); return }
                            editing = account
                            showEditor = true
                        } label: {
                            HStack {
                                Image(systemName: account.kind.iconName)
                                    .foregroundStyle(InpensoTheme.tide)
                                    .frame(width: 28)
                                VStack(alignment: .leading) {
                                    Text(account.name)
                                        .foregroundStyle(InpensoTheme.ink)
                                    Text(account.kind.displayName)
                                        .font(InpensoTheme.label(11))
                                        .foregroundStyle(InpensoTheme.muted)
                                }
                                Spacer()
                                Text(account.signedBalance, format: .currency(code: settings.selectedCurrency))
                                    .foregroundStyle(account.kind.countsAsLiability ? InpensoTheme.danger : InpensoTheme.ink)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        guard pro.isPro else { return }
                        offsets.map { store.accounts[$0] }.forEach(store.deleteAccount)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard pro.isPro else { pro.openPaywall(); return }
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus").foregroundStyle(InpensoTheme.copper)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            AccountEditorSheet(existing: editing) { store.upsertAccount($0) }
        }
    }
}

struct AccountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existing: FinanceAccount?
    let onSave: (FinanceAccount) -> Void

    @State private var name = ""
    @State private var kind: AccountKind = .checking
    @State private var balance = ""
    @State private var include = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $kind) {
                    ForEach(AccountKind.allCases) { Text($0.displayName).tag($0) }
                }
                TextField("Balance", text: $balance).keyboardType(.decimalPad)
                Toggle("Include in net worth", isOn: $include)
            }
            .navigationTitle(existing == nil ? "New account" : "Edit account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let value = Double(balance.replacingOccurrences(of: ",", with: ".")) ?? 0
                        guard !name.isEmpty else { return }
                        onSave(FinanceAccount(
                            id: existing?.id ?? UUID(),
                            name: name,
                            kind: kind,
                            balance: abs(value),
                            includeInNetWorth: include
                        ))
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    kind = existing.kind
                    balance = String(format: "%.2f", existing.balance)
                    include = existing.includeInNetWorth
                }
            }
        }
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
                    Text("When a spend title contains a match, Inpenso picks the category for you.")
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
                                    .foregroundStyle(rule.isEnabled ? InpensoTheme.tide : InpensoTheme.muted)
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
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Merchant rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard pro.isPro else { pro.openPaywall(); return }
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus").foregroundStyle(InpensoTheme.copper)
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
                            .font(InpensoTheme.label(14, weight: .bold))
                            .foregroundStyle(InpensoTheme.tide)
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
                            Circle()
                                .fill(Color(hex: member.colorHex) ?? InpensoTheme.tide)
                                .frame(width: 10, height: 10)
                            Text(member.name)
                            if member.isOwner {
                                Text("Owner")
                                    .font(InpensoTheme.label(10, weight: .bold))
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
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Household")
        .alert("Copied", isPresented: $showCopied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Invite code copied. Share it with your partner.")
        }
    }
}

// MARK: - Themes

struct ThemePacksView: View {
    @EnvironmentObject private var pro: ProEntitlementManager
    @ObservedObject private var store = PremiumDataStore.shared

    var body: some View {
        ZStack {
            AtmosphereBackground(intensity: 0.55)
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(ThemePack.all) { pack in
                        Button {
                            if !store.selectTheme(pack, isPro: pro.isPro) {
                                pro.openPaywall()
                            } else {
                                HapticFeedback.selection()
                            }
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(colors: [pack.mist, pack.ink.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Circle().fill(pack.accent).frame(width: 16, height: 16)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(pack.name)
                                            .font(InpensoTheme.body(16, weight: .bold))
                                            .foregroundStyle(InpensoTheme.ink)
                                        if pack.requiresPro {
                                            Text("PRO")
                                                .font(InpensoTheme.label(10, weight: .bold))
                                                .foregroundStyle(InpensoTheme.copper)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(InpensoTheme.copper.opacity(0.12), in: Capsule())
                                        }
                                    }
                                    Text(pack.tagline)
                                        .font(InpensoTheme.label(12))
                                        .foregroundStyle(InpensoTheme.muted)
                                }
                                Spacer()
                                if store.selectedThemeID == pack.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(InpensoTheme.tide)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("App icon")
                            .font(InpensoTheme.label(13, weight: .semibold))
                            .foregroundStyle(InpensoTheme.slate)
                        HStack(spacing: 10) {
                            ForEach(AppIconOption.allCases) { icon in
                                Button {
                                    if !store.selectIcon(icon, isPro: pro.isPro) {
                                        pro.openPaywall()
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(icon == .copper ? InpensoTheme.copper : InpensoTheme.ink)
                                            .frame(width: 52, height: 52)
                                            .overlay {
                                                if store.selectedIcon == icon {
                                                    Image(systemName: "checkmark")
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                        Text(icon.displayName)
                                            .font(InpensoTheme.label(11))
                                            .foregroundStyle(InpensoTheme.slate)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .navigationTitle("Themes & icons")
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
        List {
            Section {
                Text("Next 30 days of recurring charges & income.")
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
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pair.1.title)
                                    .font(InpensoTheme.body(15, weight: .semibold))
                                Text(pair.0, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                    .font(InpensoTheme.label(12))
                                    .foregroundStyle(InpensoTheme.muted)
                            }
                            Spacer()
                            Text(pair.1.amount, format: .currency(code: settings.selectedCurrency))
                                .foregroundStyle(pair.1.type == .income ? InpensoTheme.positive : InpensoTheme.ink)
                        }
                    }
                }
            }
        }
        .navigationTitle("This month")
    }
}
