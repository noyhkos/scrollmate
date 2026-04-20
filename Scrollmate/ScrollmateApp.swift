import SwiftUI

extension Notification.Name {
    static let scrollmateWidgetStateChanged = Notification.Name("scrollmateWidgetStateChanged")
}

@main
struct ScrollmateApp: App {
    init() {
        // Widget extension signals state change → main app syncs UI immediately
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .scrollmateWidgetStateChanged, object: nil)
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
                    NotificationManager.shared.setupNotificationCategory()
                }
                .task {
                    // Restore purchased tiers on every launch
                    await StoreKitManager.shared.restoreOnLaunch()
                }
        }
    }
}
