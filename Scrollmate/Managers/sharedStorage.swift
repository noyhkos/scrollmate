import Foundation

let APP_GROUP_ID = "group.com.scrollmate.app"

let NOTIFICATION_INTERVAL_KEY = "notificationInterval"
let DEFAULT_NOTIFICATION_INTERVAL = 5

let ACTIVE_TIMERS_KEY = "activeTimers"

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
}
