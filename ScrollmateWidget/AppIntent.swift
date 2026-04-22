import AppIntents
import UserNotifications
import WidgetKit

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Scrollmate Timer"

    func perform() async throws -> some IntentResult {
        await performTimerToggle()
        return .result()
    }
}

// Shared toggle logic used by both ToggleTimerIntent and ToggleScrollmateIntent
func performTimerToggle() async {
    let isActive = !SharedStorage.shared.activeTimers.isEmpty

    if isActive {
        let startTime = SharedStorage.shared.activeTimers[scrollmateTimerKey]
        if let startTime {
            SharedStorage.shared.addSession(start: startTime, end: Date())
        }
        SharedStorage.shared.activeTimers = [:]
        cancelReminderNotifications()
        if let startTime { sendEndNotification(startTime: startTime) }
    } else {
        let now = Date()
        SharedStorage.shared.activeTimers[scrollmateTimerKey] = now
        let interval = SharedStorage.shared.notificationInterval
        sendStartNotification(intervalMinutes: interval)
        scheduleRepeatingNotification(intervalMinutes: interval, startTime: now)
    }

    // Flush UserDefaults before widgets read the updated state
    try? await Task.sleep(nanoseconds: 200_000_000)
    WidgetCenter.shared.reloadAllTimelines()
    ControlCenter.shared.reloadAllControls()

    // Signal main app to sync UI state
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName(darwinStateChangedNotification as CFString),
        nil, nil, true
    )
}
