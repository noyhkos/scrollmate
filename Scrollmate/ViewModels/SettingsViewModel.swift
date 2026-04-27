import Foundation
import Combine
import WidgetKit

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var selectedInterval: Int
    @Published var isEnabled: Bool

    static let validIntervals = [1, 2, 3, 4] + Array(stride(from: 5, through: 60, by: 5))

    private var cancellables = Set<AnyCancellable>()

    init() {
        let stored = SharedStorage.shared.notificationInterval
        // Sanitize legacy values — round up to nearest valid 5-minute step
        let sanitized = Self.validIntervals.first { $0 >= stored } ?? 5
        if sanitized != stored {
            SharedStorage.shared.notificationInterval = sanitized
        }
        selectedInterval = sanitized
        isEnabled = SyncEngine.shared.isActive

        // Sync state when user stops from notification banner
        NotificationCenter.default.publisher(for: scrollmateStopNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isEnabled = false
            }
            .store(in: &cancellables)

        // Sync state when widget or control center toggles timer
        NotificationCenter.default.publisher(for: .scrollmateWidgetStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncState() }
            .store(in: &cancellables)
    }

    // Re-sync isEnabled from cross-process state (call on foreground resume)
    func syncState() {
        SyncEngine.shared.resyncFromStorage()
        isEnabled = SyncEngine.shared.isActive
        let stored = SharedStorage.shared.notificationInterval
        let sanitized = Self.validIntervals.first { $0 >= stored } ?? 5
        selectedInterval = sanitized
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            SyncEngine.shared.startSession(intervalMinutes: selectedInterval)
        } else {
            SyncEngine.shared.stopSession()
        }
    }

    func intervalChanged(to interval: Int) {
        selectedInterval = interval
        SharedStorage.shared.notificationInterval = interval
        if isEnabled, let startTime = SharedStorage.shared.activeTimers[scrollmateTimerKey] {
            Task.detached {
                scheduleRepeatingNotification(intervalMinutes: interval, startTime: startTime)
            }
        }
    }
}
