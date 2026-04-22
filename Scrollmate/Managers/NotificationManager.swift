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
            scheduleRepeatingNotification(intervalMinutes: interval, startTime: startTime)
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
                scheduleRepeatingNotification(intervalMinutes: interval, startTime: startTime)
            }
        }

        guard response.actionIdentifier == "STOP" else { return }
        Task { @MainActor in
            if let startTime = SharedStorage.shared.activeTimers[scrollmateTimerKey] {
                SharedStorage.shared.addSession(start: startTime, end: Date())
                sendEndNotification(startTime: startTime)
            }
            SharedStorage.shared.activeTimers = [:]
            cancelReminderNotifications()
            // Delay to ensure UserDefaults is flushed before widget reads it
            try? await Task.sleep(nanoseconds: 100_000_000)
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadAllControls()
            NotificationCenter.default.post(name: scrollmateStopNotification, object: nil)
        }
    }
}
