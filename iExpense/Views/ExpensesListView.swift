//
//  ExpensesListView.swift
//  iExpense
//

import SwiftUI

struct ExpensesListView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore

    @ObservedObject var viewModel: ExpenseViewModel
    @StateObject private var analyticsViewModel = AnalyticsViewModel(expenses: [])

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var recentlyDeletedExpenses: [Expense] = []
    @State private var showUndoSnackbar = false
    @State private var undoTimer: Timer?
    @State private var selectedExpenseToEdit: Expense?
    @State private var showingFilterSheet = false
    @State private var selectedSortOption: SortOption = .dateDescending
    @State private var selectedTransactionFilter: TransactionFilter = .all
    @State private var searchText = ""
    @State private var selectedCategoryIDs: Set<String> = []
    @State private var isListLoaded = false

    private let monthHistoryLength = 61
    private let listRowInsets = EdgeInsets(
        top: InpensoTheme.Space.sm,
        leading: InpensoTheme.Space.screen,
        bottom: InpensoTheme.Space.sm,
        trailing: InpensoTheme.Space.screen
    )

    enum SortOption: String, CaseIterable, Identifiable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case amountDescending = "Highest Amount"
        case amountAscending = "Lowest Amount"
        case titleAscending = "Title A-Z"

        var id: String { rawValue }
    }

    enum TransactionFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case expenses = "Expenses"
        case incomes = "Income"

        var id: String { rawValue }

        func matches(_ transaction: Expense) -> Bool {
            switch self {
            case .all:
                return true
            case .expenses:
                return transaction.type == .expense
            case .incomes:
                return transaction.type == .income
            }
        }
    }

    private var currencyCode: String {
        settingsViewModel.selectedCurrency
    }

    private var filteredExpenses: [Expense] {
        var result = viewModel.expenses.filter { expense in
            let month = Calendar.current.component(.month, from: expense.date)
            let year = Calendar.current.component(.year, from: expense.date)
            let category = categoryStore.category(for: expense)

            let matchesDate = month == selectedMonth && year == selectedYear
            let matchesSearch = searchText.isEmpty ||
                expense.title.localizedCaseInsensitiveContains(searchText) ||
                category.displayName.localizedCaseInsensitiveContains(searchText) ||
                (expense.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesCategory = selectedCategoryIDs.isEmpty || selectedCategoryIDs.contains(expense.categoryID)
            let matchesType = selectedTransactionFilter.matches(expense)

            return matchesDate && matchesSearch && matchesCategory && matchesType
        }

        switch selectedSortOption {
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .amountDescending:
            result.sort { $0.price > $1.price }
        case .amountAscending:
            result.sort { $0.price < $1.price }
        case .titleAscending:
            result.sort { $0.title < $1.title }
        }

        return result
    }

    private var totalSpent: Double {
        filteredExpenses.filter { $0.type == .expense }.reduce(0) { $0 + $1.price }
    }

    private var totalIncome: Double {
        filteredExpenses.filter { $0.type == .income }.reduce(0) { $0 + $1.price }
    }

    private var netCashflow: Double {
        totalIncome - totalSpent
    }

    private var groupedExpenses: [String: [Expense]] {
        Dictionary(grouping: filteredExpenses) { $0.categoryID }
    }

    private var filterCategories: [FinanceCategory] {
        categoryStore.categoriesForFilter(usedCategoryIDs: Set(viewModel.expenses.map(\.categoryID)))
    }

    private var filterCategoryIDs: [String] {
        filterCategories.map(\.id)
    }

    private var visibleCategoryIDs: [String] {
        categoryStore.orderedCategoryIDs(for: Set(groupedExpenses.keys))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                VStack(spacing: 0) {
                    monthYearPicker
                        .padding(.top, InpensoTheme.Space.xs)

                    typeFilterChips
                        .inpensoScreenPadding()
                        .padding(.top, InpensoTheme.Space.sm)

                    if !filteredExpenses.isEmpty {
                        summaryStats
                            .inpensoScreenPadding()
                            .padding(.top, InpensoTheme.Space.md)
                            .padding(.bottom, InpensoTheme.Space.sm)
                    }

                    if filteredExpenses.isEmpty {
                        emptyStateView
                            .transition(.opacity)
                            .animation(.easeInOut, value: filteredExpenses.isEmpty)
                    } else {
                        transactionList
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search transactions")
            .navigationTitle("Activity")
            .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    toolbarFilters
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenQuickAdd"), object: nil)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(InpensoTheme.ink)
                    }
                }
            }
            .tint(InpensoTheme.ink)
            .refreshable {
                refreshExpenses()
            }
            .onAppear {
                analyticsViewModel.updateExpenses(viewModel.expenses)
                if selectedCategoryIDs.isEmpty {
                    selectedCategoryIDs = Set(filterCategoryIDs)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        isListLoaded = true
                    }
                }
            }
            .onChange(of: filterCategoryIDs) { oldCategoryIDs, newCategoryIDs in
                syncSelectedCategoryIDs(oldCategoryIDs: oldCategoryIDs, newCategoryIDs: newCategoryIDs)
            }
            .onChange(of: viewModel.expenses) {
                analyticsViewModel.updateExpenses(viewModel.expenses)
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
            .overlay(undoSnackbar, alignment: .bottom)
        }
    }

    // MARK: - List

    private var transactionList: some View {
        List {
            ForEach(visibleCategoryIDs, id: \.self) { categoryID in
                let category = categoryStore.category(for: categoryID)
                let items = groupedExpenses[categoryID] ?? []

                Section {
                    ForEach(items) { expense in
                        ExpenseRowContent(
                            expense: expense,
                            currencyCode: currencyCode,
                            onEdit: {
                                selectedExpenseToEdit = expense
                            },
                            onDelete: {
                                deleteExpenseByID(expense)
                            }
                        )
                        .listRowInsets(listRowInsets)
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(InpensoTheme.hairline)
                        .listRowBackground(InpensoTheme.panelFill)
                    }
                } header: {
                    categorySectionHeader(category: category, items: items)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(InpensoTheme.panelFill)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: InpensoTheme.Space.bottomClearance - 40)
        }
        .opacity(isListLoaded ? 1 : 0)
        .animation(.easeIn(duration: 0.3), value: isListLoaded)
    }

    private func categorySectionHeader(category: FinanceCategory, items: [Expense]) -> some View {
        let categoryTotal = items.reduce(0) { total, transaction in
            total + (transaction.type == .income ? transaction.price : -transaction.price)
        }

        return HStack(spacing: InpensoTheme.Space.sm) {
            Image(systemName: category.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(category.color)
                .frame(width: 24, height: 24)

            Text(category.displayName)
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(InpensoTheme.ink)

            Spacer()

            Text(categoryTotal, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(13))
                .foregroundStyle(categoryTotal >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint)
        }
        .padding(.horizontal, InpensoTheme.Space.screen)
        .padding(.vertical, InpensoTheme.Space.xs)
        .textCase(.none)
        .listRowInsets(EdgeInsets())
        .background(InpensoTheme.foam)
    }

    // MARK: - Filters & summary

    private var typeFilterChips: some View {
        HStack(spacing: InpensoTheme.Space.xs) {
            ForEach(TransactionFilter.allCases) { filter in
                typeChip(filter)
            }
        }
    }

    private func typeChip(_ filter: TransactionFilter) -> some View {
        let selected = selectedTransactionFilter == filter
        let tint: Color = {
            switch filter {
            case .all: return InpensoTheme.ink
            case .expenses: return InpensoTheme.expenseTint
            case .incomes: return InpensoTheme.incomeTint
            }
        }()

        return Button {
            HapticFeedback.selection()
            withAnimation(InpensoTheme.Motion.snappy) {
                selectedTransactionFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(selected ? .white : InpensoTheme.slate)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        .fill(selected ? tint : InpensoTheme.mist)
                )
        }
        .buttonStyle(.plain)
    }

    private var summaryStats: some View {
        VStack(spacing: InpensoTheme.Space.sm) {
            HStack(spacing: 0) {
                statCell(title: "Income", amount: totalIncome, color: InpensoTheme.incomeTint)
                statDivider
                statCell(title: "Spent", amount: totalSpent, color: InpensoTheme.expenseTint)
                statDivider
                statCell(title: "Net", amount: netCashflow, color: netCashflow >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint)
                statDivider
                VStack(alignment: .leading, spacing: InpensoTheme.Space.xxs) {
                    Text("Count")
                        .font(InpensoTheme.label(11))
                        .foregroundStyle(InpensoTheme.muted)
                    Text("\(filteredExpenses.count)")
                        .font(InpensoTheme.displayAmount(16))
                        .foregroundStyle(InpensoTheme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if analyticsViewModel.currentBudget > 0 {
                budgetProgress
            }
        }
        .padding(.vertical, InpensoTheme.Space.sm)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(InpensoTheme.hairline)
            .frame(width: 1, height: 36)
            .padding(.horizontal, InpensoTheme.Space.xs)
    }

    private func statCell(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xxs) {
            Text(title)
                .font(InpensoTheme.label(11))
                .foregroundStyle(InpensoTheme.muted)
            Text(amount, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(14))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetProgress: some View {
        VStack(spacing: InpensoTheme.Space.xs) {
            HStack {
                Text("Budget")
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(InpensoTheme.muted)
                Spacer()
                Text("\(totalSpent.formatted(.currency(code: currencyCode))) / \(analyticsViewModel.currentBudget.formatted(.currency(code: currencyCode)))")
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(InpensoTheme.muted)
            }

            let progress = min(1.0, totalSpent / analyticsViewModel.currentBudget)
            let progressColor: Color = progress >= 0.9 ? InpensoTheme.expenseTint : (progress >= 0.75 ? InpensoTheme.ink : InpensoTheme.tide)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(InpensoTheme.mist)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(progressColor)
                        .frame(width: max(4, geometry.size.width * CGFloat(progress)), height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func syncSelectedCategoryIDs(oldCategoryIDs: [String], newCategoryIDs: [String]) {
        let oldSet = Set(oldCategoryIDs)
        let newSet = Set(newCategoryIDs)
        selectedCategoryIDs.formUnion(newSet.subtracting(oldSet))
        selectedCategoryIDs = selectedCategoryIDs.intersection(newSet)
    }

    private var toolbarFilters: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            Menu {
                Picker("Sort by", selection: $selectedSortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(InpensoTheme.ink)
            }

            Button {
                showingFilterSheet = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(InpensoTheme.ink)
            }
        }
    }

    private var monthYearPicker: some View {
        MonthYearPicker(
            selectedMonth: $selectedMonth,
            selectedYear: $selectedYear,
            monthsToShow: monthHistoryLength
        )
        .inpensoScreenPadding()
    }

    // MARK: - Empty & undo

    private var emptyStateView: some View {
        VStack(spacing: InpensoTheme.Space.md) {
            Spacer()

            Text("No activity")
                .font(InpensoTheme.sectionLabel())
                .foregroundStyle(InpensoTheme.ink)

            if !searchText.isEmpty {
                Text("Adjust search or filters.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                    .multilineTextAlignment(.center)
            } else if selectedCategoryIDs.count < filterCategoryIDs.count {
                Text("Select more categories to show results.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                    .multilineTextAlignment(.center)

                Button {
                    selectedCategoryIDs = Set(filterCategoryIDs)
                } label: {
                    Text("Reset filters")
                        .font(InpensoTheme.label(14, weight: .semibold))
                        .foregroundStyle(InpensoTheme.tide)
                }
                .padding(.top, InpensoTheme.Space.xs)
            } else {
                Text("No transactions for \(Calendar.current.monthSymbols[selectedMonth - 1]) \(String(selectedYear)).")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                    .multilineTextAlignment(.center)

                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenQuickAdd"), object: nil)
                } label: {
                    Text("Add transaction")
                }
                .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.copper))
                .frame(maxWidth: 220)
                .padding(.top, InpensoTheme.Space.xs)
            }

            Spacer()
        }
        .inpensoScreenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var undoSnackbar: some View {
        VStack {
            Spacer()
            if showUndoSnackbar {
                HStack(spacing: InpensoTheme.Space.sm) {
                    Text("Deleted")
                        .font(InpensoTheme.body(14, weight: .medium))
                        .foregroundStyle(InpensoTheme.ink)

                    Spacer()

                    Button("Undo") {
                        undoDelete()
                    }
                    .font(InpensoTheme.label(14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.tide)
                }
                .padding(InpensoTheme.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                        .fill(InpensoTheme.panelFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                                .stroke(InpensoTheme.hairline, lineWidth: 1)
                        )
                )
                .inpensoScreenPadding()
                .padding(.bottom, InpensoTheme.Space.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(InpensoTheme.Motion.snappy, value: showUndoSnackbar)
            }
        }
    }

    private func refreshExpenses() {
        viewModel.loadExpenses()
    }

    private func deleteExpenseByID(_ expense: Expense) {
        if let index = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) {
            recentlyDeletedExpenses = [expense]
            viewModel.expenses.remove(at: index)
            viewModel.saveExpenses()

            showUndoSnackbar = true

            undoTimer?.invalidate()
            undoTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                showUndoSnackbar = false
                recentlyDeletedExpenses.removeAll()
            }
        }
    }

    private func undoDelete() {
        undoTimer?.invalidate()
        viewModel.expenses.append(contentsOf: recentlyDeletedExpenses)
        viewModel.saveExpenses()
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
                        Button {
                            toggleCategory(category.id)
                        } label: {
                            HStack(spacing: InpensoTheme.Space.sm) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(category.color)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        category.color.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                    )

                                Text(category.displayName)
                                    .font(InpensoTheme.body(15))
                                    .foregroundStyle(InpensoTheme.ink)

                                Spacer()

                                if tempSelectedCategoryIDs.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(InpensoTheme.ink)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(
                            top: InpensoTheme.Space.sm,
                            leading: InpensoTheme.Space.screen,
                            bottom: InpensoTheme.Space.sm,
                            trailing: InpensoTheme.Space.screen
                        ))
                        .listRowBackground(InpensoTheme.panelFill)
                    }
                } header: {
                    Text("Categories")
                        .font(InpensoTheme.sectionLabel())
                        .foregroundStyle(InpensoTheme.muted)
                } footer: {
                    Text("At least one category must remain selected.")
                        .font(InpensoTheme.body(12))
                        .foregroundStyle(InpensoTheme.muted)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AtmosphereBackground())
            .listRowSeparatorTint(InpensoTheme.hairline)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(InpensoTheme.ink)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(InpensoTheme.muted)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        selectedCategoryIDs = tempSelectedCategoryIDs
                        dismiss()
                    }
                    .font(InpensoTheme.label(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                }
            }
        }
    }

    private func toggleCategory(_ id: String) {
        if tempSelectedCategoryIDs.contains(id) {
            if tempSelectedCategoryIDs.count > 1 {
                tempSelectedCategoryIDs.remove(id)
            }
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
            .onTapGesture {
                onEdit()
            }
            .contextMenu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .trailing) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(InpensoTheme.tide)
            }
    }
}

#Preview {
    ExpensesListView(viewModel: ExpenseViewModel())
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
