import Combine
import Foundation
import UIKit
import UserNotifications
import WidgetKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationAsync()
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorization() {
        Task { await checkAuthorizationAsync() }
    }

    private func checkAuthorizationAsync() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // nonisolated — UNUserNotificationCenter calls use XPC and must not run on main thread
    nonisolated func setupNotificationCategory() {
        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM",
            title: String(localized: "notification.action.confirm"),
            options: []
        )
        let stopAction = UNNotificationAction(
            identifier: "STOP",
            title: String(localized: "notification.action.stop"),
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: reminderCategoryId,
            actions: [confirmAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    nonisolated func sendStartNotification(intervalMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.start.title")
        content.body = String(format: String(localized: "notification.start.body"), intervalMinutes)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: startNotificationId,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func sendEndNotification(startTime: Date) {
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.end.title")
        content.body = String(format: String(localized: "notification.end.body"), usageDurationLabel(seconds: elapsed))
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: endNotificationId,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Schedule up to 63 notifications aligned to startTime — registers category and clears existing ones first
    nonisolated func scheduleRepeatingNotification(intervalMinutes: Int, startTime: Date) {
        setupNotificationCategory()
        let reminderIds = (1...63).map { "\(reminderNotificationIdPrefix).\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)

        let elapsedSeconds = Int(Date().timeIntervalSince(startTime))
        let elapsedMinutes = elapsedSeconds / 60
        // First future interval index from start (e.g. at 25min with 10min interval → next is index 3 = 30min)
        let startIndex = elapsedMinutes / intervalMinutes + 1

        for i in 0..<63 {
            let minutesFromStart = (startIndex + i) * intervalMinutes
            let secondsFromNow = minutesFromStart * 60 - elapsedSeconds
            guard secondsFromNow > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification.reminder.title")
            content.body = elapsedLabel(minutes: minutesFromStart)
            content.sound = .default
            content.categoryIdentifier = reminderCategoryId
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(secondsFromNow),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "\(reminderNotificationIdPrefix).\(i + 1)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    nonisolated func cancelReminderNotifications() {
        let reminderIds = (1...63).map { "\(reminderNotificationIdPrefix).\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])

        // Replenish the notification queue whenever a reminder fires while the app is in the foreground
        guard notification.request.identifier.hasPrefix(reminderNotificationIdPrefix) else { return }
        Task { @MainActor in
            guard let startTime = SharedStorage.shared.activeTimers[scrollmateTimerKey] else { return }
            let interval = SharedStorage.shared.notificationInterval
            NotificationManager.shared.scheduleRepeatingNotification(intervalMinutes: interval, startTime: startTime)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()

        // Replenish on any reminder interaction (user tapped from background)
        if response.notification.request.identifier.hasPrefix(reminderNotificationIdPrefix),
           response.actionIdentifier != "STOP" {
            Task { @MainActor in
                guard let startTime = SharedStorage.shared.activeTimers[scrollmateTimerKey] else { return }
                let interval = SharedStorage.shared.notificationInterval
                NotificationManager.shared.scheduleRepeatingNotification(intervalMinutes: interval, startTime: startTime)
            }
        }

        guard response.actionIdentifier == "STOP" else { return }
        Task { @MainActor in
            if let startTime = SharedStorage.shared.activeTimers[scrollmateTimerKey] {
                SharedStorage.shared.addSession(start: startTime, end: Date())
                NotificationManager.shared.sendEndNotification(startTime: startTime)
            }
            SharedStorage.shared.activeTimers = [:]
            NotificationManager.shared.cancelReminderNotifications()
            // Delay to ensure UserDefaults is flushed before widget reads it
            try? await Task.sleep(nanoseconds: 100_000_000)
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadAllControls()
            NotificationCenter.default.post(name: scrollmateStopNotification, object: nil)
        }
    }
}
