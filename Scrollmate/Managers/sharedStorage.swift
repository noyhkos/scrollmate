import Foundation

// Shared across app and widget targets — must be defined here
let kScrollmateStopNotification = Notification.Name("ScrollmateStopFromBanner")

// Defined here so both app and widget extension targets can access it via sharedStorage.swift
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

    func addTimer(for appName: String) {
        activeTimers[appName] = Date()
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
