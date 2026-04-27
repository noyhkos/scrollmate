import SwiftUI
import WidgetKit

extension Notification.Name {
    static let scrollmateWidgetStateChanged = Notification.Name("scrollmateWidgetStateChanged")
}

@main
struct ScrollmateApp: App {
    init() {
        // Widget/Control Center process signals state change → main app re-reads
        // SoT and refreshes its UI + all surfaces. ControlWidget intents run in
        // the widget extension process and can't reliably reach the main app's
        // surfaces directly, so this observer fills that gap.
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .scrollmateWidgetStateChanged, object: nil)
                    SyncEngine.shared.reloadAllSurfaces()
                }
            },
            darwinStateChangedNotification as CFString,
            nil, .deliverImmediately
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupReminderCategory()
                }
                .task {
                    // Restore purchased tiers on every launch
                    await StoreKitManager.shared.restoreOnLaunch()
                }
        }
    }
}
