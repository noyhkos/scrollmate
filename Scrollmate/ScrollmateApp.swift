import SwiftUI

@main
struct ScrollmateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                    NotificationManager.shared.setupNotificationCategory()
                }
        }
    }
}
