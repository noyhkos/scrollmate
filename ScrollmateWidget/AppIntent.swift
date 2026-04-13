import AppIntents
import UserNotifications
import WidgetKit

@MainActor
struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Scrollmate Timer"

    func perform() async throws -> some IntentResult {
        let isActive = !SharedStorage.shared.activeTimers.isEmpty

        if isActive {
            let startTime = SharedStorage.shared.activeTimers["scrollmate"]
            // Record session before clearing timer
            if let startTime {
                SharedStorage.shared.addSession(start: startTime, end: Date())
            }
            SharedStorage.shared.activeTimers = [:]
            let reminderIds = (1...63).map { "scrollmate.reminder.\($0)" }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)
            if let startTime { sendEndNotification(startTime: startTime) }
        } else {
            let now = Date()
            SharedStorage.shared.activeTimers["scrollmate"] = now
            let interval = SharedStorage.shared.notificationInterval
            sendStartNotification()
            scheduleNotifications(intervalMinutes: interval)
        }

        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        return .result()
    }
}
