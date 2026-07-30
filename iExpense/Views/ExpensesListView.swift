//
//  ExpensesListView.swift
//  iExpense
//
//  Banking-style activity archive — same visual language as Home.
//

import SwiftUI

struct ExpensesListView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore

    @ObservedObject var viewModel: ExpenseViewModel

    @State private var dateSelection = LedgerDateSelection(mode: .month)
    @State private var recentlyDeletedExpenses: [Expense] = []
    @State private var showUndoSnackbar = false
    @State private var undoTimer: Timer?
    @State private var selectedExpenseToEdit: Expense?
    @State private var showingFilterSheet = false
    @State private var showingSearch = false
    @State private var selectedSortOption: SortOption = .dateDescending
    @State private var selectedTransactionFilter: TransactionFilter = .all
    @State private var searchText = ""
    @State private var selectedCategoryIDs: Set<String> = []

    enum SortOption: String, CaseIterable, Identifiable {
        case dateDescending = "Newest first"
        case dateAscending = "Oldest first"
        case amountDescending = "Highest amount"
        case amountAscending = "Lowest amount"
        var id: String { rawValue }
    }

    enum TransactionFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case expenses = "Expenses"
        case incomes = "Income"
        var id: String { rawValue }

        func matches(_ transaction: Expense) -> Bool {
            switch self {
            case .all: return true
            case .expenses: return transaction.type == .expense
            case .incomes: return transaction.type == .income
            }
        }
    }

    private var currencyCode: String { settingsViewModel.selectedCurrency }
    private var periodInterval: DateInterval { dateSelection.interval() }

    private var filterCategories: [FinanceCategory] {
        categoryStore.categoriesForFilter(usedCategoryIDs: Set(viewModel.expenses.map(\.categoryID)))
    }

    private var filterCategoryIDs: [String] { filterCategories.map(\.id) }

    private var periodSpent: Double {
        PeriodTotals.spent(from: viewModel.expenses, interval: periodInterval)
    }

    private var periodIncome: Double {
        PeriodTotals.income(from: viewModel.expenses, interval: periodInterval)
    }

    private var filteredExpenses: [Expense] {
        var result = viewModel.expenses.filter { expense in
            guard !expense.isBalanceAdjustment else { return false }
            let category = categoryStore.category(for: expense)
            let matchesDate = periodInterval.contains(expense.date)
            let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = needle.isEmpty ||
                expense.title.localizedCaseInsensitiveContains(needle) ||
                category.displayName.localizedCaseInsensitiveContains(needle) ||
                (expense.notes?.localizedCaseInsensitiveContains(needle) ?? false) ||
                expense.tags.contains {
                    $0.localizedCaseInsensitiveContains(needle.replacingOccurrences(of: "#", with: ""))
                }
            let matchesCategory = selectedCategoryIDs.isEmpty || selectedCategoryIDs.contains(expense.categoryID)
            let matchesType = selectedTransactionFilter.matches(expense)
            return matchesDate && matchesSearch && matchesCategory && matchesType
        }

        switch selectedSortOption {
        case .dateDescending: result.sort { $0.date > $1.date }
        case .dateAscending: result.sort { $0.date < $1.date }
        case .amountDescending: result.sort { $0.homeAmount > $1.homeAmount }
        case .amountAscending: result.sort { $0.homeAmount < $1.homeAmount }
        }
        return result
    }

    private var dayGroups: [(day: Date, title: String, items: [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredExpenses) { calendar.startOfDay(for: $0.date) }
        let ascending = selectedSortOption == .dateAscending
        return grouped.keys.sorted { ascending ? $0 < $1 : $0 > $1 }.map { day in
            (day, dayTitle(day), grouped[day] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        summaryStrip
                        if showingSearch {
                            searchField
                        }
                        feed
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 120)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { viewModel.loadExpenses() }
            .onAppear {
                if selectedCategoryIDs.isEmpty {
                    selectedCategoryIDs = Set(filterCategoryIDs)
                }
            }
            .onChange(of: filterCategoryIDs) { oldIDs, newIDs in
                syncSelectedCategoryIDs(oldCategoryIDs: oldIDs, newCategoryIDs: newIDs)
            }
            .sheet(item: $selectedExpenseToEdit) { expenseToEdit in
                if expenseToEdit.title.isEmpty {
                    AddExpenseView(viewModel: viewModel)
                } else {
                    EditExpenseView(viewModel: viewModel, expense: expenseToEdit)
                        .id(expenseToEdit.id)
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterCategoriesView(selectedCategoryIDs: $selectedCategoryIDs, categories: filterCategories)
                    .presentationDetents([.medium])
            }
            .overlay(alignment: .bottom) { undoSnackbar }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Activity")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(InpensoTheme.ink)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    showingSearch.toggle()
                    if !showingSearch { searchText = "" }
                }
            } label: {
                Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.7)))
            }

            Menu {
                Picker("Show", selection: $selectedTransactionFilter) {
                    ForEach(TransactionFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Sort", selection: $selectedSortOption) {
                    ForEach(SortOption.allCases) { Text($0.rawValue).tag($0) }
                }
                Button("Categories…") { showingFilterSheet = true }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.7)))
            }

            Button {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenQuickAdd"),
                    object: nil,
                    userInfo: ["type": TransactionType.expense.rawValue]
                )
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [InpensoTheme.tide, Color(inpensoHex: "#0B7A58")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .shadow(color: InpensoTheme.tide.opacity(0.35), radius: 10, y: 4)
            }
            .accessibilityLabel("Add expense")
        }
    }

    private var summaryStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { dateSelection.shift(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
                Spacer()
                Text(dateSelection.summaryTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Button { dateSelection.shift(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPENT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(periodSpent, format: .currency(code: currencyCode))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("INCOME")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(periodIncome, format: .currency(code: currencyCode))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(InpensoTheme.seafoam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            BankingPeriodChips(selection: $dateSelection)
        }
        .padding(18)
        .background(BankingHeroBackground(radius: 24))
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(InpensoTheme.muted)
            TextField("Search transactions", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(InpensoTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(InpensoTheme.panelFill)
        )
    }

    // MARK: - Feed

    @ViewBuilder
    private var feed: some View {
        if filteredExpenses.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("No activity")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(InpensoTheme.ink)
                Text(emptyMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(InpensoTheme.muted)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )
        } else if selectedSortOption == .dateDescending || selectedSortOption == .dateAscending {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(dayGroups, id: \.day) { group in
                    daySection(title: group.title, items: group.items)
                }
            }
        } else {
            daySection(title: "Results", items: filteredExpenses)
        }
    }

    private func daySection(title: String, items: [Expense]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(InpensoTheme.muted)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, expense in
                    Button {
                        selectedExpenseToEdit = expense
                    } label: {
                        TransactionRowView(
                            expense: expense,
                            currencyCode: currencyCode,
                            category: categoryStore.category(for: expense),
                            showsDate: false
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { selectedExpenseToEdit = expense } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) { deleteExpenseByID(expense) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    if index < items.count - 1 {
                        Divider()
                            .overlay(InpensoTheme.hairline)
                            .padding(.leading, 66)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty { return "Nothing matches your search." }
        if selectedCategoryIDs.count < filterCategoryIDs.count {
            return "Some categories are hidden."
        }
        return "Nothing for \(dateSelection.summaryTitle)."
    }

    private var undoSnackbar: some View {
        Group {
            if showUndoSnackbar {
                HStack {
                    Text("Deleted")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(InpensoTheme.ink)
                    Spacer()
                    Button("Undo") { undoDelete() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(InpensoTheme.tide)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                        .shadow(color: InpensoTheme.ink.opacity(0.1), radius: 12, y: 4)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showUndoSnackbar)
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func syncSelectedCategoryIDs(oldCategoryIDs: [String], newCategoryIDs: [String]) {
        let oldSet = Set(oldCategoryIDs)
        let newSet = Set(newCategoryIDs)
        selectedCategoryIDs.formUnion(newSet.subtracting(oldSet))
        selectedCategoryIDs = selectedCategoryIDs.intersection(newSet)
    }

    private func deleteExpenseByID(_ expense: Expense) {
        recentlyDeletedExpenses = [expense]
        viewModel.deleteExpenses([expense])
        showUndoSnackbar = true
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            showUndoSnackbar = false
            recentlyDeletedExpenses.removeAll()
        }
    }

    private func undoDelete() {
        undoTimer?.invalidate()
        viewModel.addExpenses(recentlyDeletedExpenses)
        recentlyDeletedExpenses.removeAll()
        showUndoSnackbar = false
    }
}

struct ExpenseRowView: View {
    @EnvironmentObject private var categoryStore: CategoryStore
    let expense: Expense
    let currencyCode: String

    var body: some View {
        TransactionRowView(
            expense: expense,
            currencyCode: currencyCode,
            category: categoryStore.category(for: expense)
        )
    }
}

struct FilterCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategoryIDs: Set<String>
    let categories: [FinanceCategory]
    @State private var tempSelectedCategoryIDs: Set<String>

    init(selectedCategoryIDs: Binding<Set<String>>, categories: [FinanceCategory]) {
        self._selectedCategoryIDs = selectedCategoryIDs
        self.categories = categories
        self._tempSelectedCategoryIDs = State(initialValue: selectedCategoryIDs.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        Button { toggleCategory(category.id) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(category.color)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        category.color.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                Text(category.displayName)
                                    .foregroundStyle(InpensoTheme.ink)
                                Spacer()
                                if tempSelectedCategoryIDs.contains(category.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(InpensoTheme.tide)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Keep at least one category selected.")
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        selectedCategoryIDs = tempSelectedCategoryIDs
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleCategory(_ id: String) {
        if tempSelectedCategoryIDs.contains(id) {
            if tempSelectedCategoryIDs.count > 1 { tempSelectedCategoryIDs.remove(id) }
        } else {
            tempSelectedCategoryIDs.insert(id)
        }
    }
}

struct ExpenseRowContent: View {
    let expense: Expense
    let currencyCode: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ExpenseRowView(expense: expense, currencyCode: currencyCode)
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }
            .contextMenu {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            }
    }
}

#Preview {
    ExpensesListView(viewModel: ExpenseViewModel())
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
