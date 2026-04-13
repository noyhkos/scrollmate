import SwiftUI

@main
struct ScrollmateApp: App {
    init() {
        // Listen for stop signal from widget extension (works even when app is in background).
        // Must use a literal non-capturing closure — Swift C function pointer requirement.
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    Task { await LiveActivityManager.shared.endAllActivities() }
                }
            },
            darwinStopLiveActivityNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationManager.shared.setupNotificationCategory()
                }
        }
    }
}
