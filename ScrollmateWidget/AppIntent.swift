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
            scheduleNotifications(intervalMinutes: interval)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// Schedule 64 individual notifications, each with total elapsed time in the body
func scheduleNotifications(intervalMinutes: Int) {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()

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
        UNUserNotificationCenter.current().add(request)
    }
}

private func elapsedLabel(minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return "알림을 켠 지 \(m)분이 지났어요." }
    if m == 0 { return "알림을 켠 지 \(h)시간이 지났어요." }
    return "알림을 켠 지 \(h)시간 \(m)분이 지났어요."
}
