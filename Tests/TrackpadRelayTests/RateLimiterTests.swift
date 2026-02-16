import XCTest
@testable import TrackpadRelay

final class RateLimiterTests: XCTestCase {
    func testAllowsUnderLimit() {
        let limiter = RateLimiter(maxPerSecond: 100)
        for _ in 0..<100 {
            XCTAssertTrue(limiter.allow())
        }
    }

    func testRejectsOverLimit() {
        let limiter = RateLimiter(maxPerSecond: 10)
        for _ in 0..<10 {
            _ = limiter.allow()
        }
        XCTAssertFalse(limiter.allow())
    }

    func testResetsAfterWindow() {
        let limiter = RateLimiter(maxPerSecond: 5)
        for _ in 0..<5 {
            _ = limiter.allow()
        }
        XCTAssertFalse(limiter.allow())

        // Simulate time passing
        limiter.reset()
        XCTAssertTrue(limiter.allow())
    }
}
