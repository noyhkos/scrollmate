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

func sendStartNotification() {
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

func sendEndNotification(startTime: Date) {
    let elapsed = Int(Date().timeIntervalSince(startTime))
    let h = elapsed / 3600
    let m = (elapsed % 3600) / 60
    let label: String
    if h > 0 && m > 0 { label = "\(h)시간 \(m)분 사용" }
    else if h > 0 { label = "\(h)시간 사용" }
    else if m > 0 { label = "\(m)분 사용" }
    else { label = "1분 미만 사용" }

    let content = UNMutableNotificationContent()
    content.title = "Scrollmate 기록 종료!"
    content.body = "Let's Move On — \(label)"
    content.sound = .default
    let request = UNNotificationRequest(
        identifier: "scrollmate.end",
        content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
    )
    UNUserNotificationCenter.current().add(request)
}

private func registerNotificationCategory() {
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

func scheduleNotifications(intervalMinutes: Int) {
    registerNotificationCategory()
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
