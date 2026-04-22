import SwiftUI
import WidgetKit

extension Notification.Name {
    static let scrollmateWidgetStateChanged = Notification.Name("scrollmateWidgetStateChanged")
}

@main
struct ScrollmateApp: App {
    init() {
        // Widget extension signals state change → main app syncs UI and reloads all widgets
        // This is necessary because ControlWidget intents run in a separate process
        // and cannot reliably trigger home/lock screen widget reloads directly
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .scrollmateWidgetStateChanged, object: nil)
                    WidgetCenter.shared.reloadAllTimelines()
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
