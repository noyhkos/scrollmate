import Foundation
import UserNotifications
import WidgetKit

// Shared across app and widget targets — must be defined here
nonisolated let scrollmateStopNotification = Notification.Name("ScrollmateStopFromBanner")

// Darwin notification for cross-process state sync (widget → main app)
nonisolated let darwinStateChangedNotification = "com.scrollmate.stateChanged"

// MARK: - Notification Keys & Identifiers

nonisolated let scrollmateTimerKey = "scrollmate"
nonisolated let startNotificationId = "scrollmate.start"
nonisolated let endNotificationId = "scrollmate.end"
nonisolated let reminderNotificationIdPrefix = "scrollmate.reminder"
nonisolated let reminderCategoryId = "SCROLLMATE_REMINDER"

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
let TIP_TIER_KEY = "tipTier"

// MARK: - Tip Tier

enum TipTier: Int, Codable, Comparable, CaseIterable {
    case none    = 0
    case bronze  = 1
    case silver  = 2
    case gold    = 3
    case emerald = 4
    case diamond = 5

    static func < (lhs: TipTier, rhs: TipTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var productId: String? {
        switch self {
        case .none:    return nil
        case .bronze:  return "com.scrollmate.tip.bronze"
        case .silver:  return "com.scrollmate.tip.silver"
        case .gold:    return "com.scrollmate.tip.gold"
        case .emerald: return "com.scrollmate.tip.emerald"
        case .diamond: return "com.scrollmate.tip.diamond"
        }
    }

    var price: String {
        switch self {
        case .none:    return ""
        case .bronze:  return "$0.99"
        case .silver:  return "$2.99"
        case .gold:    return "$4.99"
        case .emerald: return "$9.99"
        case .diamond: return "$14.99"
        }
    }
}

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
            defaults.synchronize()
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
            defaults.synchronize()
        }
    }

    // MARK: - Tip Tier Storage

    var purchasedTier: TipTier {
        get {
            let raw = defaults.integer(forKey: TIP_TIER_KEY)
            return TipTier(rawValue: raw) ?? .none
        }
        set {
            // Always accept the purchase; display the highest tier ever purchased
            let highest = max(newValue, purchasedTier)
            defaults.set(highest.rawValue, forKey: TIP_TIER_KEY)
            defaults.synchronize()
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

// MARK: - Shared Notification Helpers
//
// Free functions so both the main app and the widget extension share a single
// source of truth. UNUserNotificationCenter is thread-safe, so these run from
// any isolation context.

nonisolated func setupReminderCategory() {
    let confirmAction = UNNotificationAction(
        identifier: "CONFIRM",
        title: String(localized: "notification.action.confirm"),
        options: []
    )
    let stopAction = UNNotificationAction(
        identifier: "STOP",
        title: String(localized: "notification.action.stop"),
        options: [.destructive]
    )
    let category = UNNotificationCategory(
        identifier: reminderCategoryId,
        actions: [confirmAction, stopAction],
        intentIdentifiers: [],
        options: [.customDismissAction]
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
}

nonisolated func sendStartNotification(intervalMinutes: Int) {
    let content = UNMutableNotificationContent()
    content.title = String(localized: "notification.start.title")
    content.body = String(format: String(localized: "notification.start.body"), intervalMinutes)
    content.sound = .default
    let request = UNNotificationRequest(
        identifier: startNotificationId,
        content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
    )
    UNUserNotificationCenter.current().add(request)
}

nonisolated func sendEndNotification(startTime: Date) {
    let elapsed = Int(Date().timeIntervalSince(startTime))
    let content = UNMutableNotificationContent()
    content.title = String(localized: "notification.end.title")
    content.body = String(format: String(localized: "notification.end.body"), usageDurationLabel(seconds: elapsed))
    content.sound = .default
    let request = UNNotificationRequest(
        identifier: endNotificationId,
        content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
    )
    UNUserNotificationCenter.current().add(request)
}

// Schedule 59 normal reminders + 1 exhausted final notice (60th) aligned to startTime
nonisolated func scheduleRepeatingNotification(intervalMinutes: Int, startTime: Date) {
    setupReminderCategory()
    let reminderIds = (1...60).map { "\(reminderNotificationIdPrefix).\($0)" }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)

    let elapsedSeconds = Int(Date().timeIntervalSince(startTime))
    let elapsedMinutes = elapsedSeconds / 60
    // First future interval index from start (e.g. at 25min with 10min interval → next is index 3 = 30min)
    let startIndex = elapsedMinutes / intervalMinutes + 1

    for i in 0..<60 {
        let minutesFromStart = (startIndex + i) * intervalMinutes
        let secondsFromNow = minutesFromStart * 60 - elapsedSeconds
        guard secondsFromNow > 0 else { continue }

        let content = UNMutableNotificationContent()
        let isLast = (i == 59)
        content.title = String(localized: isLast ? "notification.exhausted.title" : "notification.reminder.title")
        content.body = isLast
            ? String(localized: "notification.exhausted.body")
            : elapsedLabel(minutes: minutesFromStart)
        content.sound = .default
        content.categoryIdentifier = reminderCategoryId
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(secondsFromNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "\(reminderNotificationIdPrefix).\(i + 1)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

nonisolated func cancelReminderNotifications() {
    let reminderIds = (1...60).map { "\(reminderNotificationIdPrefix).\($0)" }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)
}
