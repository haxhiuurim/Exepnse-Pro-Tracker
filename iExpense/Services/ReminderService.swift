//
//  ReminderService.swift
//  iExpense
//
//  Daily log reminders so spending stays complete.
//

import Foundation
import UserNotifications

@MainActor
final class ReminderService: ObservableObject {
    static let shared = ReminderService()

    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
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

    private enum Keys {
        static let enabled = "dailyReminderEnabled"
        static let hour = "dailyReminderHour"
        static let minute = "dailyReminderMinute"
        static let requestID = "inpenso.daily.spend.reminder"
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        reminderHour = UserDefaults.standard.object(forKey: Keys.hour) as? Int ?? 20
        reminderMinute = UserDefaults.standard.object(forKey: Keys.minute) as? Int ?? 0
    }

    var reminderDate: Date {
        var comps = DateComponents()
        comps.hour = reminderHour
        comps.minute = reminderMinute
        return Calendar.current.date(from: comps) ?? Date()
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
        center.removePendingNotificationRequests(withIdentifiers: [Keys.requestID])

        guard isEnabled else { return }
        let allowed = await requestPermissionIfNeeded()
        guard allowed else {
            if isEnabled {
                UserDefaults.standard.set(false, forKey: Keys.enabled)
                isEnabled = false
            }
            return
        }

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let content = UNMutableNotificationContent()
        content.title = "Log today's spending"
        content.body = "Quick tip: open Inpenso and tap + to capture what you spent."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Keys.requestID, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
