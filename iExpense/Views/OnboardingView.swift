//
//  OnboardingView.swift
//  iExpense
//
//  First-launch setup → Available Today aha moment.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: OnboardingStore
    @ObservedObject var settings: SettingsViewModel

    @State private var step = 0
    @State private var incomeText = ""
    @State private var savingsText = ""
    @State private var budgetText = ""
    @State private var selectedCurrency: String

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
                    welcomePage.tag(0)
                    currencyPage.tag(1)
                    moneyPage.tag(2)
                    readyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(InpensoTheme.Motion.snappy, value: step)

                bottomBar
            }
        }
    }

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.lg) {
            Spacer()
            Text(AppBrand.name)
                .font(InpensoTheme.brandFont(40, weight: .heavy))
                .foregroundStyle(InpensoTheme.ink)
            Text(AppBrand.tagline)
                .font(InpensoTheme.body(18))
                .foregroundStyle(InpensoTheme.slate)
            Text("Private by default. Log fast. Know what you can spend today.")
                .font(InpensoTheme.body(15))
                .foregroundStyle(InpensoTheme.muted)
            Spacer()
        }
        .padding(InpensoTheme.Space.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currencyPage: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            Text("Home currency")
                .font(InpensoTheme.brandFont(28, weight: .bold))
                .foregroundStyle(InpensoTheme.ink)
            Text("Totals and Available Today use this currency. You can still log trips in other currencies.")
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
                Text("Your monthly picture")
                    .font(InpensoTheme.brandFont(28, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                Text("Rough numbers are fine — you can change them later in Settings.")
                    .font(InpensoTheme.body(15))
                    .foregroundStyle(InpensoTheme.muted)

                field(title: "Monthly income", text: $incomeText, placeholder: "0")
                field(title: "Monthly savings goal", text: $savingsText, placeholder: "0")
                field(title: "Monthly spend budget", text: $budgetText, placeholder: "Optional")
            }
            .padding(InpensoTheme.Space.screen)
        }
    }

    private var readyPage: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            Spacer()
            Text("You’re set")
                .font(InpensoTheme.brandFont(28, weight: .bold))
                .foregroundStyle(InpensoTheme.ink)
            Text("Home shows Available Today. Use the Trips tab to split weekends and dinners with friends. Quick Add accepts “Coffee 4.50”.")
                .font(InpensoTheme.body(15))
                .foregroundStyle(InpensoTheme.muted)

            SurfacePanel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(InpensoTheme.label(12))
                        .foregroundStyle(InpensoTheme.muted)
                    Text(previewAvailable, format: .currency(code: selectedCurrency))
                        .font(InpensoTheme.displayAmount(32))
                        .foregroundStyle(InpensoTheme.tide)
                    Text("Estimated Available Today")
                        .font(InpensoTheme.label(13))
                        .foregroundStyle(InpensoTheme.slate)
                }
            }
            Spacer()
        }
        .padding(InpensoTheme.Space.screen)
    }

    private var bottomBar: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            if step > 0 {
                Button("Back") {
                    withAnimation { step -= 1 }
                }
                .buttonStyle(InpensoSecondaryButtonStyle())
            }

            Button(step == 3 ? "Start tracking" : "Continue") {
                if step < 3 {
                    withAnimation { step += 1 }
                } else {
                    finish()
                }
            }
            .buttonStyle(InpensoPrimaryButtonStyle())
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

    private var previewAvailable: Double {
        let income = Double(incomeText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let savings = Double(savingsText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let days = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        let day = Calendar.current.component(.day, from: Date())
        let remaining = max(1, days - day + 1)
        return max(0, (income - savings) / Double(remaining))
    }

    private func finish() {
        let income = Double(incomeText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let savings = Double(savingsText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let budget = Double(budgetText.replacingOccurrences(of: ",", with: ".")) ?? 0
        settings.selectedCurrency = selectedCurrency
        store.complete(
            currencyCode: selectedCurrency,
            monthlyIncome: income,
            monthlySavingsTarget: savings,
            monthlyBudget: budget
        )
    }
}
