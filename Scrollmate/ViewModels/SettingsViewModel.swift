import Foundation
import Combine
import WidgetKit

@MainActor
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
        NotificationCenter.default.publisher(for: scrollmateStopNotification)
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
        // Pre-capture on main actor before entering detached task
        let nm = NotificationManager.shared
        if enabled {
            SharedStorage.shared.activeTimers["scrollmate"] = Date()
            SharedStorage.shared.notificationInterval = selectedInterval
            nm.sendStartNotification()
            // scheduleRepeatingNotification has removePending + 63 adds — detach to avoid blocking
            let interval = selectedInterval
            Task.detached {
                nm.scheduleRepeatingNotification(intervalMinutes: interval)
            }
        } else {
            let startTime = SharedStorage.shared.activeTimers["scrollmate"]
            if let startTime {
                SharedStorage.shared.addSession(start: startTime, end: Date())
            }
            SharedStorage.shared.removeTimer(for: "scrollmate")
            if let startTime {
                nm.sendEndNotification(startTime: startTime)
            }
            Task.detached {
                nm.cancelReminderNotifications()
            }
        }
        // Single reload point for widget and control center
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }

    func intervalChanged(to interval: Int) {
        selectedInterval = interval
        SharedStorage.shared.notificationInterval = interval
        if isEnabled {
            let nm = NotificationManager.shared
            Task.detached {
                nm.scheduleRepeatingNotification(intervalMinutes: interval)
            }
        }
    }
}
