import SwiftUI

@main
struct ScrollmateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Register notification category — checkAuthorization is called in ScrollTabView.onAppear
                    NotificationManager.shared.setupNotificationCategory()
                }
        }
    }
}
