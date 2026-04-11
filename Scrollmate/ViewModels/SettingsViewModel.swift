import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var selectedInterval: Int
    @Published var isEnabled: Bool

    init() {
        selectedInterval = SharedStorage.shared.notificationInterval
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