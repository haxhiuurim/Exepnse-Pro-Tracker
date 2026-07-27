//
//  ReminderService.swift
//  iExpense
//
//  Configurable spending reminders — frequency + time of day.
//

import Foundation
import UserNotifications

enum ReminderFrequency: String, CaseIterable, Identifiable, Codable {
    case daily
    case weekdays
    case everyTwoDays
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Every day"
        case .weekdays: return "Weekdays only"
        case .everyTwoDays: return "Every 2 days"
        case .weekly: return "Once a week"
        }
    }

    var footerHint: String {
        switch self {
        case .daily: return "A reminder every day at the time you choose."
        case .weekdays: return "Monday–Friday at the time you choose."
        case .everyTwoDays: return "Every other day at the time you choose."
        case .weekly: return "Once a week on the weekday you pick."
        }
    }
}

@MainActor
final class ReminderService: ObservableObject {
    static let shared = ReminderService()

    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            Task { await syncSchedule() }
        }
    }

    @Published var frequency: ReminderFrequency = .daily {
        didSet {
            UserDefaults.standard.set(frequency.rawValue, forKey: Keys.frequency)
            Task { await syncSchedule() }
        }
    }

    @Published var reminderHour: Int = 20 {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: Keys.hour)
            Task { await syncSchedule() }
        }
    }

    @Published var reminderMinute: Int = 0 {
        didSet {
            UserDefaults.standard.set(reminderMinute, forKey: Keys.minute)
            Task { await syncSchedule() }
        }
    }

    /// 1 = Sunday … 7 = Saturday (Calendar weekday)
    @Published var weeklyWeekday: Int = 2 {
        didSet {
            UserDefaults.standard.set(weeklyWeekday, forKey: Keys.weekday)
            Task { await syncSchedule() }
        }
    }

    private enum Keys {
        static let enabled = "dailyReminderEnabled"
        static let frequency = "reminderFrequency"
        static let hour = "dailyReminderHour"
        static let minute = "dailyReminderMinute"
        static let weekday = "reminderWeekday"
        static let requestPrefix = "inpenso.spend.reminder."
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        if let raw = UserDefaults.standard.string(forKey: Keys.frequency),
           let freq = ReminderFrequency(rawValue: raw) {
            frequency = freq
        }
        reminderHour = UserDefaults.standard.object(forKey: Keys.hour) as? Int ?? 20
        reminderMinute = UserDefaults.standard.object(forKey: Keys.minute) as? Int ?? 0
        weeklyWeekday = UserDefaults.standard.object(forKey: Keys.weekday) as? Int ?? 2
    }

    var reminderDate: Date {
        var comps = DateComponents()
        comps.hour = reminderHour
        comps.minute = reminderMinute
        return Calendar.current.date(from: comps) ?? Date()
    }

    var weekdaySymbol: String {
        let symbols = Calendar.current.weekdaySymbols
        let index = max(0, min(symbols.count - 1, weeklyWeekday - 1))
        return symbols[index]
    }

    func setReminderTime(from date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        reminderHour = comps.hour ?? 20
        reminderMinute = comps.minute ?? 0
    }

    func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        default:
            return false
        }
    }

    func syncSchedule() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let oldIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Keys.requestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        guard isEnabled else { return }
        let allowed = await requestPermissionIfNeeded()
        guard allowed else {
            if isEnabled {
                UserDefaults.standard.set(false, forKey: Keys.enabled)
                isEnabled = false
            }
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Log your spending"
        content.body = "Open \(AppBrand.name) and tap + to capture what you spent."
        content.sound = .default

        switch frequency {
        case .daily:
            var comps = DateComponents()
            comps.hour = reminderHour
            comps.minute = reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            try? await center.add(UNNotificationRequest(
                identifier: Keys.requestPrefix + "daily",
                content: content,
                trigger: trigger
            ))

        case .weekdays:
            for weekday in 2...6 { // Mon–Fri
                var comps = DateComponents()
                comps.weekday = weekday
                comps.hour = reminderHour
                comps.minute = reminderMinute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                try? await center.add(UNNotificationRequest(
                    identifier: Keys.requestPrefix + "weekday.\(weekday)",
                    content: content,
                    trigger: trigger
                ))
            }

        case .everyTwoDays:
            // Schedule the next 30 occurrences (iOS calendar triggers can't natively do every-N-days)
            let calendar = Calendar.current
            var next = calendar.date(
                bySettingHour: reminderHour,
                minute: reminderMinute,
                second: 0,
                of: Date()
            ) ?? Date()
            if next <= Date() {
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
            }
            for index in 0..<15 {
                let fire = calendar.date(byAdding: .day, value: index * 2, to: next) ?? next
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                try? await center.add(UNNotificationRequest(
                    identifier: Keys.requestPrefix + "bi.\(index)",
                    content: content,
                    trigger: trigger
                ))
            }

        case .weekly:
            var comps = DateComponents()
            comps.weekday = weeklyWeekday
            comps.hour = reminderHour
            comps.minute = reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            try? await center.add(UNNotificationRequest(
                identifier: Keys.requestPrefix + "weekly",
                content: content,
                trigger: trigger
            ))
        }
    }
}
