import Foundation

/// Represents the shared timer state across the app, widgets, and live activities.
/// Persisted in the app group container so extensions can stay in sync.
struct SharedTimerState: Codable {
    var startDate: Date
    var endDate: Date
    /// True when the timer is paused.
    var isPaused: Bool
    var mode: String
    var modeColorName: String
    var sessionCount: Int
    var totalSessions: Int
    /// Remaining time in seconds when the timer was paused.
    var remaining: TimeInterval

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    /// Fraction of the session that has elapsed at the given date.
    func fractionCompleted(at date: Date = Date()) -> Double {
        guard duration > 0 else { return 1 }
        if isPaused {
            return 1 - (remaining / duration)
        } else {
            let elapsed = date.timeIntervalSince(startDate)
            return min(max(elapsed / duration, 0), 1)
        }
    }
}
