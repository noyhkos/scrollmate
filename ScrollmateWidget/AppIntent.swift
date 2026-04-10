import AppIntents
import UserNotifications
import WidgetKit

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Scrollmate Timer"

    func perform() async throws -> some IntentResult {
        let isActive = !SharedStorage.shared.activeTimers.isEmpty

        if isActive {
            SharedStorage.shared.activeTimers = [:]
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        } else {
            SharedStorage.shared.addTimer(for: "scrollmate")

            let interval = SharedStorage.shared.notificationInterval
            let content = UNMutableNotificationContent()
            content.title = "스크롤 중이세요?"
            content.body = "SNS를 사용한 지 \(interval)분이 지났어요."
            content.sound = .default
            content.categoryIdentifier = "SCROLLMATE_REMINDER"

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(interval * 60),
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "scrollmate.reminder",
                content: content,
                trigger: trigger
            )
            try await UNUserNotificationCenter.current().add(request)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
