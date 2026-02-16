import Foundation

final class RateLimiter {
    private let maxPerSecond: Int
    private var eventCount: Int = 0
    private var windowStart: Date = Date()

    init(maxPerSecond: Int = 1000) {
        self.maxPerSecond = maxPerSecond
    }

    /// Returns true if the event is allowed, false if rate-limited.
    func allow() -> Bool {
        let now = Date()

        if now.timeIntervalSince(windowStart) >= 1.0 {
            eventCount = 0
            windowStart = now
        }

        eventCount += 1
        return eventCount <= maxPerSecond
    }

    func reset() {
        eventCount = 0
        windowStart = Date()
    }
}
