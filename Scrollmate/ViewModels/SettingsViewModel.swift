import Foundation
import Combine

// Posted by NotificationManager when user taps "알림 끄기" from banner
let kScrollmateStopNotification = Notification.Name("ScrollmateStopFromBanner")

class SettingsViewModel: ObservableObject {
    @Published var selectedInterval: Int
    @Published var isEnabled: Bool

    static let validIntervals = Array(stride(from: 5, through: 60, by: 5))

    private var cancellables = Set<AnyCancellable>()

    init() {
        let stored = SharedStorage.shared.notificationInterval
        // Sanitize legacy values — round up to nearest valid 5-minute step
        let sanitized = Self.validIntervals.first { $0 >= stored } ?? 5
        if sanitized != stored {
            SharedStorage.shared.notificationInterval = sanitized
        }
        selectedInterval = sanitized
        isEnabled = !SharedStorage.shared.activeTimers.isEmpty

        // Sync state when user stops from notification banner
        NotificationCenter.default.publisher(for: kScrollmateStopNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isEnabled = false
            }
            .store(in: &cancellables)
    }

    // Re-sync isEnabled from SharedStorage (call on foreground resume)
    func syncState() {
        isEnabled = !SharedStorage.shared.activeTimers.isEmpty
        let stored = SharedStorage.shared.notificationInterval
        let sanitized = Self.validIntervals.first { $0 >= stored } ?? 5
        selectedInterval = sanitized
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
            // Record session before clearing timer
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
