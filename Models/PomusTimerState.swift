import Foundation

/// Shared timer model persisted in the app group so the app, widget and
/// live activity remain in perfect sync.
struct PomusTimerState: Codable, Hashable {
    enum Status: String, Codable, Hashable {
        case idle
        case focus
        case breakTime
        case paused
    }

    var status: Status = .idle
    var startDate: Date? = nil
    var endDate: Date? = nil
    /// Date when the timer was paused. Nil if running.
    var pauseDate: Date? = nil
    /// Total amount of time spent paused across the session.
    var accumulatedPause: TimeInterval = 0

    var sessionCount: Int = 0
    var totalSessions: Int = 0
    var modeName: String = ""
    var modeColorName: String = "FocusColor"

    /// Computes fraction completed for the provided date using the stored
    /// start/end dates and accumulated pause duration. The device clock is
    /// used as the only source of truth so progress advances even when the
    /// app is not running.
    func fractionCompleted(at date: Date = Date()) -> Double {
        guard let start = startDate, let end = endDate else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        let effectiveNow = (status == .paused ? (pauseDate ?? date) : date)
        let elapsed = effectiveNow.timeIntervalSince(start) - accumulatedPause
        return min(max(elapsed / total, 0), 1)
    }

    /// Remaining time for the provided date.
    func remainingTime(at date: Date = Date()) -> TimeInterval {
        guard let start = startDate, let end = endDate else { return 0 }
        let total = end.timeIntervalSince(start)
        let elapsedFraction = fractionCompleted(at: date)
        return max(0, total * (1 - elapsedFraction))
    }

    /// Convenience flag to know if the timer is actively counting.
    var isRunning: Bool { status == .focus || status == .breakTime }
}
