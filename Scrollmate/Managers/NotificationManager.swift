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

    // Schedule up to 64 individual notifications (iOS limit), each showing total elapsed time
    func scheduleRepeatingNotification(intervalMinutes: Int) {
        cancelAllNotifications()

        let maxCount = 64
        for i in 1...maxCount {
            let elapsedMinutes = intervalMinutes * i

            let content = UNMutableNotificationContent()
            content.title = "스크롤 중이세요?"
            content.body = elapsedLabel(minutes: elapsedMinutes)
            content.sound = .default
            content.categoryIdentifier = "SCROLLMATE_REMINDER"

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(elapsedMinutes * 60),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "scrollmate.reminder.\(i)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("Notification \(i) scheduling failed: \(error)")
                }
            }
        }
    }

    private func elapsedLabel(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "알림을 켠 지 \(m)분이 지났어요." }
        if m == 0 { return "알림을 켠 지 \(h)시간이 지났어요." }
        return "알림을 켠 지 \(h)시간 \(m)분이 지났어요."
    }

    // Test only — fires a single notification after 10 seconds
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "스크롤 중이세요?"
        content.body = "알림을 켠 지 10초가 지났어요. (테스트)"
        content.sound = .default
        content.categoryIdentifier = "SCROLLMATE_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "scrollmate.test", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
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
            // Record session before clearing timer
            if let startTime = SharedStorage.shared.activeTimers["scrollmate"] {
                SharedStorage.shared.addSession(start: startTime, end: Date())
            }
            SharedStorage.shared.activeTimers = [:]
            cancelAllNotifications()
            WidgetCenter.shared.reloadAllTimelines()
            // Notify SettingsViewModel to update isEnabled on main thread
            NotificationCenter.default.post(name: kScrollmateStopNotification, object: nil)
        }
        // CONFIRM and UNNotificationDismissActionIdentifier → timer continues, do nothing
        completionHandler()
    }
}
