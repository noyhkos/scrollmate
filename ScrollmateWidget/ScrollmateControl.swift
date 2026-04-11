import AppIntents
import UserNotifications
import WidgetKit
import SwiftUI

// Reads current timer state to reflect on/off in the Control Center toggle
struct ScrollmateControlProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        return !SharedStorage.shared.activeTimers.isEmpty
    }
}

// SetValueIntent required by ControlWidgetToggle — value is the new on/off state
struct ToggleScrollmateIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Toggle Scrollmate"

    @Parameter(title: "Is On")
    var value: Bool

    func perform() async throws -> some IntentResult {
        if value {
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
        } else {
            SharedStorage.shared.activeTimers = [:]
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct ScrollmateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.scrollmate.app.controlcenter",
            provider: ScrollmateControlProvider()
        ) { isOn in
            ControlWidgetToggle(
                isOn: isOn,
                action: ToggleScrollmateIntent()
            ) {
                Label("Scrollmate", systemImage: isOn ? "stop.fill" : "play.fill")
            }
        }
        .displayName("Scrollmate")
        .description("알림 시작/종료")
    }
}
