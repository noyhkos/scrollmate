import AppIntents
import UserNotifications
import WidgetKit

@MainActor
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
        sendStartNotification()
        scheduleRepeatingNotification(intervalMinutes: interval, startTime: now)
    }

    WidgetCenter.shared.reloadAllTimelines()
    ControlCenter.shared.reloadAllControls()

    // Signal main app to sync UI state
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName(darwinStateChangedNotification as CFString),
        nil, nil, true
    )
}

private func setupNotificationCategory() {
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

private func sendStartNotification() {
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

private func sendEndNotification(startTime: Date) {
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

private func scheduleRepeatingNotification(intervalMinutes: Int, startTime: Date) {
    setupNotificationCategory()
    let reminderIds = (1...63).map { "\(reminderNotificationIdPrefix).\($0)" }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)

    let elapsedSeconds = Int(Date().timeIntervalSince(startTime))
    let elapsedMinutes = elapsedSeconds / 60
    let startIndex = elapsedMinutes / intervalMinutes + 1

    for i in 0..<63 {
        let minutesFromStart = (startIndex + i) * intervalMinutes
        let secondsFromNow = minutesFromStart * 60 - elapsedSeconds
        guard secondsFromNow > 0 else { continue }

        let content = UNMutableNotificationContent()
        content.title = "스크롤 중이세요?"
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

private func cancelReminderNotifications() {
    let reminderIds = (1...63).map { "\(reminderNotificationIdPrefix).\($0)" }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)
}
