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

    @State private var dateSelection = LedgerDateSelection(mode: .month)
    @State private var recentlyDeletedExpenses: [Expense] = []
    @State private var showUndoSnackbar = false
    @State private var undoTimer: Timer?
    @State private var selectedExpenseToEdit: Expense?
    @State private var showingFilterSheet = false
    @State private var selectedSortOption: SortOption = .dateDescending
    @State private var selectedTransactionFilter: TransactionFilter = .all
    @State private var searchText = ""
    @State private var selectedCategoryIDs: Set<String> = []

    private let screenInset = InpensoTheme.Space.screen

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
            case .all: return true
            case .expenses: return transaction.type == .expense
            case .incomes: return transaction.type == .income
            }
        }
    }

    private var currencyCode: String {
        settingsViewModel.selectedCurrency
    }

    private var periodInterval: DateInterval {
        dateSelection.interval()
    }

    private var filteredExpenses: [Expense] {
        var result = viewModel.expenses.filter { expense in
            let category = categoryStore.category(for: expense)
            let matchesDate = periodInterval.contains(expense.date)
            let matchesSearch = searchText.isEmpty ||
                expense.title.localizedCaseInsensitiveContains(searchText) ||
                category.displayName.localizedCaseInsensitiveContains(searchText) ||
                (expense.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesCategory = selectedCategoryIDs.isEmpty || selectedCategoryIDs.contains(expense.categoryID)
            let matchesType = selectedTransactionFilter.matches(expense)
            return matchesDate && matchesSearch && matchesCategory && matchesType
        }

        switch selectedSortOption {
        case .dateDescending: result.sort { $0.date > $1.date }
        case .dateAscending: result.sort { $0.date < $1.date }
        case .amountDescending: result.sort { $0.price > $1.price }
        case .amountAscending: result.sort { $0.price < $1.price }
        case .titleAscending: result.sort { $0.title < $1.title }
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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                        brandHeader
                        periodHero
                        typeFilterChips
                        searchAndTools
                        activityContent
                    }
                    .padding(.horizontal, screenInset)
                    .padding(.top, InpensoTheme.Space.sm)
                    .padding(.bottom, InpensoTheme.Space.bottomClearance)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { viewModel.loadExpenses() }
            .onAppear {
                analyticsViewModel.updateExpenses(viewModel.expenses)
                if selectedCategoryIDs.isEmpty {
                    selectedCategoryIDs = Set(filterCategoryIDs)
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

    // MARK: - Header

    private var brandHeader: some View {
        HStack(alignment: .center, spacing: InpensoTheme.Space.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activity")
                    .font(InpensoTheme.brandFont(28, weight: .heavy))
                    .foregroundStyle(InpensoTheme.ink)
                Text(dateSelection.summaryTitle)
                    .font(InpensoTheme.label(13))
                    .foregroundStyle(InpensoTheme.muted)
            }

            Spacer(minLength: 8)

            headerIconButton("minus.circle.fill", tint: InpensoTheme.expenseTint, label: "Add expense") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenQuickAdd"),
                    object: nil,
                    userInfo: ["type": TransactionType.expense.rawValue]
                )
            }
            headerIconButton("plus.circle.fill", tint: InpensoTheme.incomeTint, label: "Add income") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenQuickAdd"),
                    object: nil,
                    userInfo: ["type": TransactionType.income.rawValue]
                )
            }
        }
    }

    private func headerIconButton(_ systemImage: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(InpensoTheme.panelFill)
                        .shadow(color: InpensoTheme.ink.opacity(0.06), radius: 8, y: 2)
                )
        }
        .accessibilityLabel(label)
    }

    // MARK: - Period hero

    private var periodHero: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            rangeModePicker

            HStack {
                Button {
                    dateSelection.shift(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(InpensoTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(InpensoTheme.mist, in: Circle())
                }

                Spacer()

                Text(dateSelection.summaryTitle)
                    .font(InpensoTheme.label(14, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button {
                    dateSelection.shift(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(InpensoTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(InpensoTheme.mist, in: Circle())
                }
            }

            HStack(spacing: 0) {
                summaryCell(title: "Spent", amount: totalSpent, tint: InpensoTheme.expenseTint)
                summaryDivider
                summaryCell(title: "Income", amount: totalIncome, tint: InpensoTheme.incomeTint)
                summaryDivider
                summaryCell(
                    title: "Net",
                    amount: netCashflow,
                    tint: netCashflow >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint
                )
            }

            if dateSelection.mode == .month,
               analyticsViewModel.currentBudget > 0,
               Calendar.current.isDate(dateSelection.anchor, equalTo: Date(), toGranularity: .month) {
                budgetProgress
            }
        }
        .padding(InpensoTheme.Space.md)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
    }

    private var rangeModePicker: some View {
        HStack(spacing: 0) {
            ForEach(LedgerRangeMode.allCases) { mode in
                let selected = dateSelection.mode == mode
                Button {
                    HapticFeedback.selection()
                    withAnimation(InpensoTheme.Motion.snappy) {
                        dateSelection.mode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(InpensoTheme.label(13, weight: .bold))
                        .foregroundStyle(selected ? .white : InpensoTheme.slate)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                .fill(selected ? InpensoTheme.ink : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                .fill(InpensoTheme.mist)
        )
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(InpensoTheme.hairline)
            .frame(width: 1, height: 36)
            .padding(.horizontal, InpensoTheme.Space.xs)
    }

    private func summaryCell(title: String, amount: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xxs) {
            Text(title)
                .font(InpensoTheme.label(11, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
                .textCase(.uppercase)
            Text(amount, format: .currency(code: currencyCode))
                .font(InpensoTheme.displayAmount(15))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetProgress: some View {
        VStack(spacing: InpensoTheme.Space.xs) {
            HStack {
                Text("Monthly budget")
                    .font(InpensoTheme.label(11, weight: .semibold))
                    .foregroundStyle(InpensoTheme.muted)
                Spacer()
                Text("\(totalSpent.formatted(.currency(code: currencyCode))) / \(analyticsViewModel.currentBudget.formatted(.currency(code: currencyCode)))")
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(InpensoTheme.muted)
            }

            let progress = min(1.0, totalSpent / max(analyticsViewModel.currentBudget, 0.01))
            let progressColor: Color = progress >= 0.9 ? InpensoTheme.expenseTint : (progress >= 0.75 ? InpensoTheme.ink : InpensoTheme.tide)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(InpensoTheme.mist)
                        .frame(height: 5)
                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(5, geometry.size.width * CGFloat(progress)), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Filters

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
                .font(InpensoTheme.label(13, weight: .bold))
                .foregroundStyle(selected ? .white : InpensoTheme.slate)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                        .fill(selected ? tint : InpensoTheme.mist)
                )
        }
        .buttonStyle(.plain)
    }

    private var searchAndTools: some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            HStack(spacing: InpensoTheme.Space.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(InpensoTheme.muted)
                TextField("Search transactions", text: $searchText)
                    .font(InpensoTheme.body(15))
                    .foregroundStyle(InpensoTheme.ink)
            }
            .padding(.horizontal, InpensoTheme.Space.md)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )

            Menu {
                Picker("Sort by", selection: $selectedSortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                            .fill(InpensoTheme.panelFill)
                    )
            }

            Button {
                showingFilterSheet = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        selectedCategoryIDs.count < filterCategoryIDs.count
                            ? InpensoTheme.tide
                            : InpensoTheme.ink
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                            .fill(InpensoTheme.panelFill)
                    )
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var activityContent: some View {
        if filteredExpenses.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: InpensoTheme.Space.section) {
                ForEach(visibleCategoryIDs, id: \.self) { categoryID in
                    let category = categoryStore.category(for: categoryID)
                    let items = groupedExpenses[categoryID] ?? []
                    categorySection(category: category, items: items)
                }
            }
        }
    }

    private func categorySection(category: FinanceCategory, items: [Expense]) -> some View {
        let categoryTotal = items.reduce(0) { total, transaction in
            total + (transaction.type == .income ? transaction.price : -transaction.price)
        }

        return VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            HStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: category.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(category.color)
                    .frame(width: 28, height: 28)
                    .background(
                        category.color.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Text(category.displayName)
                    .font(InpensoTheme.label(13, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)

                Spacer()

                Text(categoryTotal, format: .currency(code: currencyCode))
                    .font(InpensoTheme.displayAmount(13))
                    .foregroundStyle(categoryTotal >= 0 ? InpensoTheme.incomeTint : InpensoTheme.expenseTint)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, expense in
                    Button {
                        selectedExpenseToEdit = expense
                    } label: {
                        TransactionRowView(
                            expense: expense,
                            currencyCode: currencyCode,
                            category: categoryStore.category(for: expense)
                        )
                        .padding(.horizontal, InpensoTheme.Space.md)
                        .padding(.vertical, InpensoTheme.Space.sm)
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
                        Divider().overlay(InpensoTheme.hairline).padding(.leading, 68)
                    }
                }
            }
            .inpensoPanelBackground(radius: InpensoTheme.Radius.lg)
        }
    }

    private var emptyState: some View {
        VStack(spacing: InpensoTheme.Space.md) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(InpensoTheme.muted.opacity(0.5))

            Text("No activity")
                .font(InpensoTheme.brandFont(22, weight: .bold))
                .foregroundStyle(InpensoTheme.ink)

            if !searchText.isEmpty {
                Text("Nothing matches your search.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                    .multilineTextAlignment(.center)
            } else if selectedCategoryIDs.count < filterCategoryIDs.count {
                Text("Category filters are hiding transactions for this period.")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                    .multilineTextAlignment(.center)

                Button {
                    selectedCategoryIDs = Set(filterCategoryIDs)
                } label: {
                    Text("Show all categories")
                        .font(InpensoTheme.label(14, weight: .bold))
                        .foregroundStyle(InpensoTheme.tide)
                }
            } else {
                Text("No transactions for \(dateSelection.summaryTitle).")
                    .font(InpensoTheme.body(14))
                    .foregroundStyle(InpensoTheme.muted)
                    .multilineTextAlignment(.center)

                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenQuickAdd"), object: nil)
                } label: {
                    Text("Add transaction")
                }
                .buttonStyle(InpensoPrimaryButtonStyle(tint: InpensoTheme.ink))
                .frame(maxWidth: 220)
            }
        }
        .padding(InpensoTheme.Space.xl)
        .frame(maxWidth: .infinity)
        .inpensoPanelBackground(radius: InpensoTheme.Radius.hero)
    }

    private var undoSnackbar: some View {
        VStack {
            Spacer()
            if showUndoSnackbar {
                HStack(spacing: InpensoTheme.Space.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)

                    Text("Transaction deleted")
                        .font(InpensoTheme.body(14, weight: .medium))
                        .foregroundStyle(InpensoTheme.ink)

                    Spacer()

                    Button("Undo") { undoDelete() }
                        .font(InpensoTheme.label(14, weight: .bold))
                        .foregroundStyle(InpensoTheme.tide)
                }
                .padding(InpensoTheme.Space.md)
                .inpensoPanelBackground(radius: InpensoTheme.Radius.md)
                .padding(.horizontal, screenInset)
                .padding(.bottom, InpensoTheme.Space.bottomClearance - 56)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(InpensoTheme.Motion.snappy, value: showUndoSnackbar)
            }
        }
    }

    private func syncSelectedCategoryIDs(oldCategoryIDs: [String], newCategoryIDs: [String]) {
        let oldSet = Set(oldCategoryIDs)
        let newSet = Set(newCategoryIDs)
        selectedCategoryIDs.formUnion(newSet.subtracting(oldSet))
        selectedCategoryIDs = selectedCategoryIDs.intersection(newSet)
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
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(InpensoTheme.tide)
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
                    Button("Cancel") { dismiss() }
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
            .onTapGesture { onEdit() }
            .contextMenu {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            }
            .swipeActions(edge: .leading) {
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            }
            .swipeActions(edge: .trailing) {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                    .tint(InpensoTheme.tide)
            }
    }
}

#Preview {
    ExpensesListView(viewModel: ExpenseViewModel())
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
