import Foundation
import UIKit
import UserNotifications
import WidgetKit
import Combine

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Requests permission and returns whether it was granted
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

    // @MainActor class — no need for MainActor.run inside async method
    private func checkAuthorizationAsync() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = (settings.authorizationStatus == .authorized)
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
            identifier: "SCROLLMATE_REMINDER",
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
            identifier: "scrollmate.start",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func sendEndNotification(startTime: Date) {
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let content = UNMutableNotificationContent()
        content.title = "Scrollmate 기록 종료!"
        content.body = "Let's Move On — \(durationLabel(seconds: elapsed))"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "scrollmate.end",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated private func durationLabel(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 && m > 0 { return "\(h)시간 \(m)분 사용" }
        if h > 0 { return "\(h)시간 사용" }
        if m > 0 { return "\(m)분 사용" }
        return "1분 미만 사용"
    }

    // Schedule up to 64 individual notifications — nonisolated to avoid main thread blocking
    nonisolated func scheduleRepeatingNotification(intervalMinutes: Int) {
        let reminderIds = (1...63).map { "scrollmate.reminder.\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)

        for i in 1...63 {
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
                if let error { print("Notification \(i) scheduling failed: \(error)") }
            }
        }
    }

    nonisolated private func elapsedLabel(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "알림을 켠 지 \(m)분이 지났어요." }
        if m == 0 { return "알림을 켠 지 \(h)시간이 지났어요." }
        return "알림을 켠 지 \(h)시간 \(m)분이 지났어요."
    }

    nonisolated func cancelReminderNotifications() {
        let reminderIds = (1...63).map { "scrollmate.reminder.\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // nonisolated — system calls delegate on arbitrary thread
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
        // Call completionHandler immediately — state updates run asynchronously on main actor
        completionHandler()
        guard response.actionIdentifier == "STOP" else { return }
        Task { @MainActor in
            if let startTime = SharedStorage.shared.activeTimers["scrollmate"] {
                SharedStorage.shared.addSession(start: startTime, end: Date())
                NotificationManager.shared.sendEndNotification(startTime: startTime)
            }
            SharedStorage.shared.activeTimers = [:]
            NotificationManager.shared.cancelReminderNotifications()
            LiveActivityManager.shared.stop()
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadAllControls()
            NotificationCenter.default.post(name: scrollmateStopNotification, object: nil)
        }
    }
}
