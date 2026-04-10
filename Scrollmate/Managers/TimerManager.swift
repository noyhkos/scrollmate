import Foundation
import Combine
import WidgetKit

class TimerManager: ObservableObject {
    static let shared = TimerManager()

    @Published var activeTimers: [String: Date] = [:]

    private init() {
        activeTimers = SharedStorage.shared.activeTimers
    }

    func startTimer(for appName: String) {
        activeTimers[appName] = Date()
        SharedStorage.shared.addTimer(for: appName)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func stopTimer(for appName: String) {
        activeTimers.removeValue(forKey: appName)
        SharedStorage.shared.removeTimer(for: appName)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func elapsedMinutes(for appName: String) -> Int? {
        guard let start = activeTimers[appName] else { return nil }
        return Int(Date().timeIntervalSince(start) / 60)
    }
}