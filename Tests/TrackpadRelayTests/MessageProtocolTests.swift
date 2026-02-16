import XCTest
@testable import TrackpadRelay

final class MessageProtocolTests: XCTestCase {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    func testDecodeMoveBy() throws {
        let json = #"{"type":"moveBy","dx":10.5,"dy":-3.2}"#
        let message = try decoder.decode(RelayMessage.self, from: json.data(using: .utf8)!)
        if case .moveBy(let dx, let dy) = message {
            XCTAssertEqual(dx, 10.5)
            XCTAssertEqual(dy, -3.2)
        } else {
            XCTFail("Expected moveBy")
        }
    }

    func testDecodeMoveTo() throws {
        let json = #"{"type":"moveTo","x":100,"y":200}"#
        let message = try decoder.decode(RelayMessage.self, from: json.data(using: .utf8)!)
        if case .moveTo(let x, let y) = message {
            XCTAssertEqual(x, 100)
            XCTAssertEqual(y, 200)
        } else {
            XCTFail("Expected moveTo")
        }
    }

    func testDecodeClick() throws {
        let json = #"{"type":"click","button":"left","clickType":"click"}"#
        let message = try decoder.decode(RelayMessage.self, from: json.data(using: .utf8)!)
        if case .click(let button, let type) = message {
            XCTAssertEqual(button, .left)
            XCTAssertEqual(type, .click)
        } else {
            XCTFail("Expected click")
        }
    }

    func testDecodeAuth() throws {
        let json = #"{"type":"auth","token":"my-secret"}"#
        let message = try decoder.decode(RelayMessage.self, from: json.data(using: .utf8)!)
        if case .auth(let token) = message {
            XCTAssertEqual(token, "my-secret")
        } else {
            XCTFail("Expected auth")
        }
    }

    func testDecodeScroll() throws {
        let json = #"{"type":"scroll","dx":0,"dy":-5}"#
        let message = try decoder.decode(RelayMessage.self, from: json.data(using: .utf8)!)
        if case .scroll(let dx, let dy) = message {
            XCTAssertEqual(dx, 0)
            XCTAssertEqual(dy, -5)
        } else {
            XCTFail("Expected scroll")
        }
    }

    func testRoundTrip() throws {
        let original = RelayMessage.moveBy(dx: 1.5, dy: -2.5)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RelayMessage.self, from: data)
        if case .moveBy(let dx, let dy) = decoded {
            XCTAssertEqual(dx, 1.5)
            XCTAssertEqual(dy, -2.5)
        } else {
            XCTFail("Round-trip failed")
        }
    }

    func testInvalidJSON() {
        let json = #"{"type":"invalid"}"#
        XCTAssertThrowsError(try decoder.decode(RelayMessage.self, from: json.data(using: .utf8)!))
    }
}
