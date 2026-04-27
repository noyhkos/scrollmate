import AppIntents
import UserNotifications
import WidgetKit

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Scrollmate Timer"

    func perform() async throws -> some IntentResult {
        SyncEngine.shared.toggle()
        // Hold the intent open briefly so iOS keeps the widget extension alive
        // long enough for SyncEngine's first multi-pass reload (~200ms) to fire.
        // Without this, iOS can suspend the extension before reloadAllControls
        // actually dispatches, leaving Control Center stale.
        try? await Task.sleep(nanoseconds: 300_000_000)
        return .result()
    }
}
