import ActivityKit
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
            sendStartNotification()
            scheduleNotifications(intervalMinutes: interval)
            // Start Live Activity
            let attributes = ScrollmateAttributes()
            let state = ScrollmateAttributes.ContentState(startTime: now)
            let content = ActivityContent(state: state, staleDate: nil)
            try? Activity.request(attributes: attributes, content: content)
        } else {
            let startTime = SharedStorage.shared.activeTimers["scrollmate"]
            // Record session before clearing timer
            if let startTime {
                SharedStorage.shared.addSession(start: startTime, end: Date())
            }
            SharedStorage.shared.activeTimers = [:]
            let reminderIds = (1...63).map { "scrollmate.reminder.\($0)" }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)
            if let startTime { sendEndNotification(startTime: startTime) }
            // End Live Activity
            for activity in Activity<ScrollmateAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
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
