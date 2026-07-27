//
//  QuickAddConfigurationIntent.swift
//  iExpenseWidgetExtension
//

import AppIntents
import WidgetKit

struct QuickAddConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Spending Overview"
    static var description = IntentDescription("Choose which period to show on your Expense widget.")

    @Parameter(title: "Period", default: SpendingPeriod.month)
    var period: SpendingPeriod
}

/// Opens Expense focused on the quick-add sheet.
struct OpenQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add"
    static var description = IntentDescription("Open Expense to quickly log expense or income.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Type", default: "expense")
    var transactionType: String

    init() {
        self.transactionType = "expense"
    }

    init(transactionType: String) {
        self.transactionType = transactionType
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: StorageService.appGroupID)
        defaults?.set(true, forKey: "pendingQuickAdd")
        defaults?.set(transactionType, forKey: "pendingQuickAddType")
        defaults?.synchronize()
        return .result()
    }
}

/// One-tap add from a saved template (used by large widgets).
struct AddTemplateExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Quick Spend"
    static var description = IntentDescription("Log a saved quick spend from the widget.")

    @Parameter(title: "Template ID")
    var templateID: String

    init() {
        self.templateID = ""
    }

    init(templateID: String) {
        self.templateID = templateID
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: templateID) else {
            return .result()
        }

        var templates = StorageService.loadQuickTemplates()
        guard let index = templates.firstIndex(where: { $0.id == uuid }) else {
            return .result()
        }

        var template = templates[index]
        var expenses = StorageService.loadExpenses()
        let expense = Expense(
            title: template.title,
            price: template.amount,
            date: Date(),
            category: template.category,
            type: .expense,
            categoryID: template.categoryID
        )
        expenses.append(expense)
        StorageService.saveExpenses(expenses)

        template.useCount += 1
        template.lastUsed = Date()
        templates[index] = template
        StorageService.saveQuickTemplates(templates)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
