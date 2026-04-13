import Foundation

// Shared across app and widget targets — must be defined here
let scrollmateStopNotification = Notification.Name("ScrollmateStopFromBanner")

// Darwin notification for cross-process state sync (widget → main app)
let darwinStateChangedNotification = "com.scrollmate.stateChanged"

// MARK: - Notification Keys & Identifiers

nonisolated(unsafe) let scrollmateTimerKey = "scrollmate"
nonisolated(unsafe) let startNotificationId = "scrollmate.start"
nonisolated(unsafe) let endNotificationId = "scrollmate.end"
nonisolated(unsafe) let reminderNotificationIdPrefix = "scrollmate.reminder"
nonisolated(unsafe) let reminderCategoryId = "SCROLLMATE_REMINDER"

// MARK: - Shared Formatters (available to both app and widget extension targets)

/// Reminder notification body — localized, e.g. "30 minutes since you started scrolling."
nonisolated func elapsedLabel(minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return String(format: String(localized: "elapsed.minutes"), m) }
    if m == 0 { return String(format: String(localized: "elapsed.hours"), h) }
    return String(format: String(localized: "elapsed.hours.minutes"), h, m)
}

/// End notification / session duration label — localized, e.g. "1 hr 30 min"
nonisolated func usageDurationLabel(seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    if h > 0 && m > 0 { return String(format: String(localized: "duration.hours.minutes"), h, m) }
    if h > 0 { return String(format: String(localized: "duration.hours"), h) }
    if m > 0 { return String(format: String(localized: "duration.minutes"), m) }
    return String(localized: "duration.less")
}

// Defined here so both app and widget extension targets can access it
struct ScrollSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

let APP_GROUP_ID = "group.com.scrollmate.app"

let NOTIFICATION_INTERVAL_KEY = "notificationInterval"
let DEFAULT_NOTIFICATION_INTERVAL = 5

let ACTIVE_TIMERS_KEY = "activeTimers"
let SCROLL_SESSIONS_KEY = "scrollSessions"

class SharedStorage {
    static let shared = SharedStorage()

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: APP_GROUP_ID) ?? UserDefaults.standard
    }

    var notificationInterval: Int {
        get {
            let value = defaults.integer(forKey: NOTIFICATION_INTERVAL_KEY)
            return value == 0 ? DEFAULT_NOTIFICATION_INTERVAL : value
        }
        set {
            defaults.set(newValue, forKey: NOTIFICATION_INTERVAL_KEY)
        }
    }

    var activeTimers: [String: Date] {
        get {
            let value = defaults.object(forKey: ACTIVE_TIMERS_KEY) as? [String: Date] ?? [:]
            return value
        }
        set {
            defaults.set(newValue, forKey: ACTIVE_TIMERS_KEY)
        }
    }

    func removeTimer(for appName: String) {
        activeTimers.removeValue(forKey: appName)
    }

    // MARK: - Session Storage

    private var scrollSessions: [ScrollSession] {
        get {
            guard let data = defaults.data(forKey: SCROLL_SESSIONS_KEY),
                  let sessions = try? JSONDecoder().decode([ScrollSession].self, from: data) else {
                return []
            }
            return sessions
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: SCROLL_SESSIONS_KEY)
        }
    }

    // Adds a session and discards any sessions whose endTime is not within end's calendar day
    func addSession(start: Date, end: Date) {
        let session = ScrollSession(id: UUID(), startTime: start, endTime: end)
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: end)
        var sessions = scrollSessions.filter { calendar.startOfDay(for: $0.endTime) == endDay }
        sessions.append(session)
        scrollSessions = sessions
    }

    // Returns only sessions that ended within today's calendar day
    func todaySessions() -> [ScrollSession] {
        scrollSessions.filter { Calendar.current.isDateInToday($0.endTime) }
    }
}
