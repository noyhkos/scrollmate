import Foundation
import WidgetKit

// SyncEngine — single entry point for cross-process state changes.
//
// All four toggle surfaces (in-app, home widget, lock screen widget, Control
// Center) funnel through this type. Goals:
//
//   1. One write path. New surfaces can't introduce new race conditions because
//      there's only one place that mutates state.
//   2. File-first reads. ControlValueProvider.currentValue() reads via this
//      engine, which prefers the atomic mirror file over UserDefaults so the
//      Control Center process sees fresh state even before UserDefaults
//      finishes propagating.
//   3. Multi-pass surface reload. iOS 18's Control Center is best-effort about
//      acting on reloadAllControls(); we issue the call three times across a
//      few seconds so transient drops don't leave a stale toggle.
//
// SyncEngine is a stateless namespace over SharedStorage + the system reload
// APIs. Per-process singletons exist (one in main app, one in widget extension)
// but they share the underlying SoT — App Group UserDefaults plus state.json.

final class SyncEngine {
    static let shared = SyncEngine()
    private init() {}

    // MARK: - Read Path (file-first, UserDefaults fallback)

    /// True when a scroll session is currently active.
    /// Reads the atomic mirror first; falls back to UserDefaults if the mirror
    /// doesn't exist (e.g., upgrades from an older build before the first toggle).
    var isActive: Bool {
        if let mirror = SharedStorage.shared.readStateMirror() {
            return mirror.isActive
        }
        SharedStorage.shared.forceSync()
        return !SharedStorage.shared.activeTimers.isEmpty
    }

    /// Active session start time, or nil if no session is running.
    var activeStartTime: Date? {
        if let mirror = SharedStorage.shared.readStateMirror() {
            return mirror.startTime
        }
        SharedStorage.shared.forceSync()
        return SharedStorage.shared.activeTimers[scrollmateTimerKey]
    }

    // MARK: - Write Path

    /// Begin a session. Writes UserDefaults + atomic mirror, schedules the
    /// start notification + repeating reminders, then issues a multi-pass
    /// surface reload and posts the cross-process Darwin notification.
    func startSession(intervalMinutes: Int) {
        let now = Date()
        SharedStorage.shared.activeTimers[scrollmateTimerKey] = now
        SharedStorage.shared.notificationInterval = intervalMinutes
        bumpStateVersion()
        writeMirror(isActive: true, startTime: now)

        sendStartNotification(intervalMinutes: intervalMinutes)
        Task.detached {
            scheduleRepeatingNotification(intervalMinutes: intervalMinutes, startTime: now)
        }

        scheduleMultiPassReload()
        postDarwinStateChanged()
    }

    /// End the active session. Saves to history, sends the end notification,
    /// cancels pending reminders, then reloads surfaces and posts Darwin.
    /// Returns the session that was ended, if any.
    @discardableResult
    func stopSession() -> ScrollSession? {
        guard let startTime = SharedStorage.shared.activeTimers[scrollmateTimerKey] else {
            // Even when nothing is active, ensure mirror reflects OFF so other
            // surfaces don't lag behind a phantom ON state.
            writeMirror(isActive: false, startTime: nil)
            scheduleMultiPassReload()
            postDarwinStateChanged()
            return nil
        }
        let endTime = Date()
        SharedStorage.shared.addSession(start: startTime, end: endTime)
        SharedStorage.shared.activeTimers = [:]
        bumpStateVersion()
        writeMirror(isActive: false, startTime: nil)

        sendEndNotification(startTime: startTime)
        Task.detached {
            cancelReminderNotifications()
        }

        scheduleMultiPassReload()
        postDarwinStateChanged()
        return ScrollSession(id: UUID(), startTime: startTime, endTime: endTime)
    }

    /// Toggle based on current state. Used by widget and Control Center
    /// intents where the user expresses intent to flip without specifying
    /// a target value.
    func toggle() {
        if isActive {
            stopSession()
        } else {
            startSession(intervalMinutes: SharedStorage.shared.notificationInterval)
        }
    }

    /// Re-read state and refresh widgets. Call when the app becomes active
    /// to recover from any drift that occurred while suspended.
    func resyncFromStorage() {
        SharedStorage.shared.forceSync()
        // Reconcile mirror in case it's missing (e.g., upgraded from older build)
        let active = !SharedStorage.shared.activeTimers.isEmpty
        let start = SharedStorage.shared.activeTimers[scrollmateTimerKey]
        writeMirror(isActive: active, startTime: start)
        scheduleMultiPassReload()
    }

    // MARK: - Surface Reload (multi-pass)

    /// Public reload hook for callers that suspect drift (e.g., Darwin observer).
    func reloadAllSurfaces() {
        scheduleMultiPassReload()
    }

    private func scheduleMultiPassReload() {
        // Three passes give iOS multiple chances to act. Reload calls are
        // idempotent and cheap; the system coalesces redundant requests.
        Task.detached {
            try? await Task.sleep(nanoseconds: 200_000_000)
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadControls(ofKind: SCROLLMATE_CONTROL_KIND)

            try? await Task.sleep(nanoseconds: 800_000_000)
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadControls(ofKind: SCROLLMATE_CONTROL_KIND)

            try? await Task.sleep(nanoseconds: 2_500_000_000)
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadControls(ofKind: SCROLLMATE_CONTROL_KIND)
        }
    }

    // MARK: - Internal Helpers

    private func bumpStateVersion() {
        SharedStorage.shared.stateVersion = SharedStorage.shared.stateVersion + 1
        SharedStorage.shared.stateUpdatedAt = Date()
    }

    private func writeMirror(isActive: Bool, startTime: Date?) {
        let mirror = SyncStateMirror(
            isActive: isActive,
            startTime: startTime,
            version: SharedStorage.shared.stateVersion,
            updatedAt: SharedStorage.shared.stateUpdatedAt ?? Date()
        )
        SharedStorage.shared.writeStateMirror(mirror)
    }

    private func postDarwinStateChanged() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinStateChangedNotification as CFString),
            nil, nil, true
        )
    }
}
