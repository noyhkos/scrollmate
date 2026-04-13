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
        let confirmAction = UNNotificationAction(identifier: "CONFIRM", title: "확인", options: [])
        let stopAction = UNNotificationAction(identifier: "STOP", title: "알림 끄기", options: [.destructive])
        let category = UNNotificationCategory(
            identifier: reminderCategoryId,
            actions: [confirmAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    nonisolated func sendStartNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Let's Scroll!"
        content.body = "기록을 시작합니다."
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
        content.title = "Scrollmate 기록 종료!"
        content.body = "Let's Move On — \(usageDurationLabel(seconds: elapsed))"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: endNotificationId,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Schedule up to 63 individual notifications — registers category and clears existing ones first
    nonisolated func scheduleRepeatingNotification(intervalMinutes: Int) {
        setupNotificationCategory()
        let reminderIds = (1...63).map { "\(reminderNotificationIdPrefix).\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)

        for i in 1...63 {
            let elapsedMinutes = intervalMinutes * i
            let content = UNMutableNotificationContent()
            content.title = "스크롤 중이세요?"
            content.body = elapsedLabel(minutes: elapsedMinutes)
            content.sound = .default
            content.categoryIdentifier = reminderCategoryId

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(elapsedMinutes * 60),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "\(reminderNotificationIdPrefix).\(i)",
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
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
        guard response.actionIdentifier == "STOP" else { return }
        Task { @MainActor in
            if let startTime = SharedStorage.shared.activeTimers[scrollmateTimerKey] {
                SharedStorage.shared.addSession(start: startTime, end: Date())
                NotificationManager.shared.sendEndNotification(startTime: startTime)
            }
            SharedStorage.shared.activeTimers = [:]
            NotificationManager.shared.cancelReminderNotifications()
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadAllControls()
            NotificationCenter.default.post(name: scrollmateStopNotification, object: nil)
        }
    }
}
