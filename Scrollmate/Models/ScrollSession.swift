import Foundation

struct ScrollSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}
