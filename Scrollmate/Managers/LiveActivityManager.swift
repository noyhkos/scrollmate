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

    func stop(startTime: Date = Date()) {
        Task {
            await endAllActivities()
        }
    }

    // Ends all active Live Activities — callable from the main app process where ActivityKit works reliably
    func endAllActivities() async {
        let finalContent = ActivityContent(
            state: ScrollmateAttributes.ContentState(startTime: activity?.content.state.startTime ?? Date()),
            staleDate: Date()
        )
        if let activity {
            await activity.end(finalContent, dismissalPolicy: .immediate)
            self.activity = nil
        }
        for act in Activity<ScrollmateAttributes>.activities {
            await act.end(finalContent, dismissalPolicy: .immediate)
        }
        SharedStorage.shared.pendingLiveActivityEnd = false
    }
}
