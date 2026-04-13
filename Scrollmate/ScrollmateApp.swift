import SwiftUI

// Global C callback for Darwin notification from widget extension
private func onDarwinStopLiveActivity(
    _: CFNotificationCenter?, _: UnsafeMutableRawPointer?,
    _: CFNotificationName?, _: UnsafeRawPointer?, _: CFDictionary?
) {
    Task { @MainActor in
        await LiveActivityManager.shared.endAllActivities()
    }
}

@main
struct ScrollmateApp: App {
    init() {
        // Listen for stop signal from widget extension (works even when app is in background)
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            onDarwinStopLiveActivity,
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
