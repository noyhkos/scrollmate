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
            let now = Date()
            SharedStorage.shared.activeTimers["scrollmate"] = now
            let interval = SharedStorage.shared.notificationInterval
            scheduleNotifications(intervalMinutes: interval)
        } else {
            // Record session before clearing timer
            if let startTime = SharedStorage.shared.activeTimers["scrollmate"] {
                SharedStorage.shared.addSession(start: startTime, end: Date())
            }
            SharedStorage.shared.activeTimers = [:]
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            // Notify app UI to sync state
            NotificationCenter.default.post(name: kScrollmateStopNotification, object: nil)
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
