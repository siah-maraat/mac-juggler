import Foundation

enum MouseButton: String, Codable {
    case left
    case right
    case center
}

enum ClickType: String, Codable {
    case down
    case up
    case click // down + up
}

enum RelayMessage: Codable {
    case auth(token: String)
    case moveTo(x: Double, y: Double)
    case moveBy(dx: Double, dy: Double)
    case click(button: MouseButton, type: ClickType)
    case scroll(dx: Double, dy: Double)

    private enum CodingKeys: String, CodingKey {
        case type
        case x, y, dx, dy
        case button, clickType
        case token
    }

    private enum MessageType: String, Codable {
        case auth
        case moveTo
        case moveBy
        case click
        case scroll
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .auth:
            let token = try container.decode(String.self, forKey: .token)
            self = .auth(token: token)
        case .moveTo:
            let x = try container.decode(Double.self, forKey: .x)
            let y = try container.decode(Double.self, forKey: .y)
            self = .moveTo(x: x, y: y)
        case .moveBy:
            let dx = try container.decode(Double.self, forKey: .dx)
            let dy = try container.decode(Double.self, forKey: .dy)
            self = .moveBy(dx: dx, dy: dy)
        case .click:
            let button = try container.decode(MouseButton.self, forKey: .button)
            let clickType = try container.decode(ClickType.self, forKey: .clickType)
            self = .click(button: button, type: clickType)
        case .scroll:
            let dx = try container.decode(Double.self, forKey: .dx)
            let dy = try container.decode(Double.self, forKey: .dy)
            self = .scroll(dx: dx, dy: dy)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .auth(let token):
            try container.encode(MessageType.auth, forKey: .type)
            try container.encode(token, forKey: .token)
        case .moveTo(let x, let y):
            try container.encode(MessageType.moveTo, forKey: .type)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
        case .moveBy(let dx, let dy):
            try container.encode(MessageType.moveBy, forKey: .type)
            try container.encode(dx, forKey: .dx)
            try container.encode(dy, forKey: .dy)
        case .click(let button, let clickType):
            try container.encode(MessageType.click, forKey: .type)
            try container.encode(button, forKey: .button)
            try container.encode(clickType, forKey: .clickType)
        case .scroll(let dx, let dy):
            try container.encode(MessageType.scroll, forKey: .type)
            try container.encode(dx, forKey: .dx)
            try container.encode(dy, forKey: .dy)
        }
    }
}

struct RelayResponse: Codable {
    let success: Bool
    let message: String?

    static func ok(_ message: String? = nil) -> RelayResponse {
        RelayResponse(success: true, message: message)
    }

    static func error(_ message: String) -> RelayResponse {
        RelayResponse(success: false, message: message)
    }
}
