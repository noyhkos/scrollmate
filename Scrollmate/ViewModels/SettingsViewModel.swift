import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var selectedInterval: Int
    @Published var isEnabled: Bool

    static let validIntervals = Array(stride(from: 5, through: 60, by: 5))

    init() {
        let stored = SharedStorage.shared.notificationInterval
        // Sanitize legacy values — round up to nearest valid 5-minute step
        let sanitized = Self.validIntervals.first { $0 >= stored } ?? 5
        if sanitized != stored {
            SharedStorage.shared.notificationInterval = sanitized
        }
        selectedInterval = sanitized
        isEnabled = !SharedStorage.shared.activeTimers.isEmpty
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            SharedStorage.shared.notificationInterval = selectedInterval
            TimerManager.shared.startTimer(for: "scrollmate")
            Task { @MainActor in
                NotificationManager.shared.scheduleRepeatingNotification(intervalMinutes: self.selectedInterval)
            }
        } else {
            // Record the session before clearing the timer
            if let startTime = SharedStorage.shared.activeTimers["scrollmate"] {
                SharedStorage.shared.addSession(start: startTime, end: Date())
            }
            TimerManager.shared.stopTimer(for: "scrollmate")
            Task { @MainActor in
                NotificationManager.shared.cancelAllNotifications()
            }
        }
    }

    func intervalChanged(to interval: Int) {
        selectedInterval = interval
        SharedStorage.shared.notificationInterval = interval
        if isEnabled {
            Task { @MainActor in
                NotificationManager.shared.scheduleRepeatingNotification(intervalMinutes: interval)
            }
        }
    }
}
