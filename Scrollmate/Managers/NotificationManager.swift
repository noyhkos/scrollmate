import Foundation
import UIKit
import UserNotifications
import WidgetKit
import Combine

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            Task { @MainActor in
                self.isAuthorized = granted
            }
        }
    }

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorized = settings.authorizationStatus == .authorized
            Task { @MainActor in
                self.isAuthorized = authorized
            }
        }
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func setupNotificationCategory() {
        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM",
            title: "확인",
            options: []
        )
        let stopAction = UNNotificationAction(
            identifier: "STOP",
            title: "알림 끄기",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "SCROLLMATE_REMINDER",
            actions: [confirmAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func scheduleRepeatingNotification(intervalMinutes: Int) {
        cancelAllNotifications()

        let content = UNMutableNotificationContent()
        content.title = "스크롤 중이세요?"
        content.body = "SNS를 사용한 지 \(intervalMinutes)분이 지났어요."
        content.sound = .default
        content.categoryIdentifier = "SCROLLMATE_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(intervalMinutes * 60),
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "scrollmate.reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle tap on notification actions (including dismiss)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "STOP" {
            SharedStorage.shared.activeTimers = [:]
            cancelAllNotifications()
            WidgetCenter.shared.reloadAllTimelines()
        }
        // CONFIRM and UNNotificationDismissActionIdentifier → timer continues, do nothing
        completionHandler()
    }
}
