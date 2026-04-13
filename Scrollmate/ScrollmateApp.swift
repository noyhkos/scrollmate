import SwiftUI

@main
struct ScrollmateApp: App {
    init() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        // Start signal from widget extension — Live Activities must be started from main app
        CFNotificationCenterAddObserver(
            center, nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    Task {
                        if let startTime = SharedStorage.shared.activeTimers["scrollmate"] {
                            await LiveActivityManager.shared.start(startTime: startTime)
                        }
                    }
                }
            },
            darwinStartLiveActivityNotification as CFString,
            nil, .deliverImmediately
        )
        // Stop signal from widget extension
        CFNotificationCenterAddObserver(
            center, nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    Task { await LiveActivityManager.shared.endAllActivities() }
                }
            },
            darwinStopLiveActivityNotification as CFString,
            nil, .deliverImmediately
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
