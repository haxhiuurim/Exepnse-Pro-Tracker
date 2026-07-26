//
//  MonthYearPicker.swift
//  iExpense
//

import SwiftUI

struct MonthYear: Identifiable, Equatable {
    var id: String { "\(month)-\(year)" }
    let month: Int
    let year: Int

    var displayName: String {
        let calendar = Calendar.current
        return "\(calendar.monthSymbols[month - 1]) \(String(year))"
    }

    func isFuture(relativeTo date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: date)
        let currentYear = calendar.component(.year, from: date)
        return (year > currentYear) || (year == currentYear && month > currentMonth)
    }
}

struct MonthYearPicker: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    private let monthYearList: [MonthYear]
    private let allowFutureMonths: Bool
    var onMonthYearChanged: (() -> Void)? = nil

    @State private var selectedIndex: Int = 0

    init(
        selectedMonth: Binding<Int>,
        selectedYear: Binding<Int>,
        monthsToShow: Int = 36,
        allowFutureMonths: Bool = false,
        onMonthYearChanged: (() -> Void)? = nil
    ) {
        self._selectedMonth = selectedMonth
        self._selectedYear = selectedYear
        self.onMonthYearChanged = onMonthYearChanged
        self.allowFutureMonths = allowFutureMonths

        var list: [MonthYear] = []
        let totalMonths = max(monthsToShow, 1)
        let calendar = Calendar.current
        if let today = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) {
            for i in (0..<totalMonths).reversed() {
                if let date = calendar.date(byAdding: .month, value: -i, to: today) {
                    let month = calendar.component(.month, from: date)
                    let year = calendar.component(.year, from: date)
                    list.append(MonthYear(month: month, year: year))
                }
            }
        }
        self.monthYearList = list

        let initialIndex = list.firstIndex(where: {
            $0.month == selectedMonth.wrappedValue && $0.year == selectedYear.wrappedValue
        }) ?? 0
        self._selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            navButton(systemName: "chevron.left", enabled: selectedIndex > 0) {
                if selectedIndex > 0 { selectedIndex -= 1 }
            }

            TabView(selection: $selectedIndex) {
                ForEach(Array(monthYearList.enumerated()), id: \.element.id) { index, monthYear in
                    Text(monthYear.displayName)
                        .font(InpensoTheme.brandFont(18, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                        .frame(maxWidth: .infinity)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 44)
            .onChange(of: selectedIndex) {
                guard monthYearList.indices.contains(selectedIndex) else { return }
                let monthYear = monthYearList[selectedIndex]

                if !allowFutureMonths && monthYear.isFuture() {
                    selectedIndex = monthYearList.firstIndex(where: {
                        $0.month == selectedMonth && $0.year == selectedYear
                    }) ?? 0
                    HapticFeedback.error()
                } else {
                    selectedMonth = monthYear.month
                    selectedYear = monthYear.year
                    HapticFeedback.selection()
                    onMonthYearChanged?()
                }
            }
            .onAppear {
                if let index = monthYearList.firstIndex(where: {
                    $0.month == selectedMonth && $0.year == selectedYear
                }) {
                    selectedIndex = index
                }
            }

            navButton(
                systemName: "chevron.right",
                enabled: selectedIndex < monthYearList.count - 1
            ) {
                if selectedIndex < monthYearList.count - 1 { selectedIndex += 1 }
            }
        }
        .padding(.horizontal, InpensoTheme.Space.sm)
        .padding(.vertical, InpensoTheme.Space.xs)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .stroke(InpensoTheme.hairline, lineWidth: 1)
                )
        )
    }

    private func navButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(InpensoTheme.body(15, weight: .semibold))
                .foregroundStyle(enabled ? InpensoTheme.ink : InpensoTheme.muted.opacity(0.35))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        .fill(enabled ? InpensoTheme.mist : Color.clear)
                )
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    MonthYearPicker(
        selectedMonth: .constant(Calendar.current.component(.month, from: Date())),
        selectedYear: .constant(Calendar.current.component(.year, from: Date()))
    )
    .padding(InpensoTheme.Space.screen)
    .background(InpensoTheme.foam)
}
