import XCTest
@testable import TrackpadRelay

final class NetworkGuardTests: XCTestCase {
    func testPrivateIPv4Ranges() {
        XCTAssertTrue(NetworkGuard.isLocalNetwork("192.168.1.1"))
        XCTAssertTrue(NetworkGuard.isLocalNetwork("192.168.0.100"))
        XCTAssertTrue(NetworkGuard.isLocalNetwork("10.0.0.1"))
        XCTAssertTrue(NetworkGuard.isLocalNetwork("10.255.255.255"))
        XCTAssertTrue(NetworkGuard.isLocalNetwork("172.16.0.1"))
        XCTAssertTrue(NetworkGuard.isLocalNetwork("172.31.255.255"))
    }

    func testLoopback() {
        XCTAssertTrue(NetworkGuard.isLocalNetwork("127.0.0.1"))
        XCTAssertTrue(NetworkGuard.isLocalNetwork("::1"))
    }

    func testIPv6LinkLocal() {
        XCTAssertTrue(NetworkGuard.isLocalNetwork("fe80::1"))
    }

    func testPublicIPsRejected() {
        XCTAssertFalse(NetworkGuard.isLocalNetwork("8.8.8.8"))
        XCTAssertFalse(NetworkGuard.isLocalNetwork("1.1.1.1"))
        XCTAssertFalse(NetworkGuard.isLocalNetwork("172.32.0.1"))
        XCTAssertFalse(NetworkGuard.isLocalNetwork("172.15.0.1"))
        XCTAssertFalse(NetworkGuard.isLocalNetwork("203.0.113.1"))
    }
}
