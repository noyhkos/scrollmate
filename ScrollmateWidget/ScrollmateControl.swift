import AppIntents
import UserNotifications
import WidgetKit
import SwiftUI

// Reads current timer state to reflect on/off in the Control Center toggle.
// Goes through SyncEngine so the read is file-first (atomic mirror) and falls
// back to UserDefaults — this minimizes stale visuals from cross-process delay.
struct ScrollmateControlProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        SyncEngine.shared.isActive
    }
}

// SetValueIntent required by ControlWidgetToggle — delegates to SyncEngine.
// We honor the system's desired value rather than blind-toggling so a stale
// CC visual that already matches the actual state doesn't double-flip.
struct ToggleScrollmateIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Toggle Scrollmate"

    @Parameter(title: "Is On")
    var value: Bool

    func perform() async throws -> some IntentResult {
        let currentlyActive = SyncEngine.shared.isActive
        if value != currentlyActive {
            SyncEngine.shared.toggle()
        }
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
        .description("control.description")
    }
}
