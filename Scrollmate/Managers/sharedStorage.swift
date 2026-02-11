import Foundation

class SharedStorage {
    static let shared = SharedStorage()

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: "group.com.scrollmate.app") ?? UserDefaults.standard
    }

    var notificationInterval: Int {
        get {
            return defaults.integer(forKey: "notificationInterval")
            return value == 0 ? 5 : value
        }
        set {
            defaults.set(newValue, forKey: "notificationInterval")
        }
    }
}