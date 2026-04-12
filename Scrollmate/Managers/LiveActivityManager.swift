import ActivityKit
import Foundation

// Manages Live Activity lifecycle from the app target
@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<ScrollmateAttributes>?

    private init() {}

    func start(startTime: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ScrollmateAttributes()
        let state = ScrollmateAttributes.ContentState(startTime: startTime)
        let content = ActivityContent(state: state, staleDate: nil)
        activity = try? Activity.request(attributes: attributes, content: content)
    }

    func stop() {
        guard let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.activity = nil
        }
    }
}
