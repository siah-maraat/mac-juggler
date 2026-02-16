import CoreGraphics
import Foundation

final class CursorController {
    func moveTo(x: Double, y: Double) {
        let point = CGPoint(x: x, y: y)
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        event?.post(tap: .cgSessionEventTap)
    }

    func moveBy(dx: Double, dy: Double) {
        let currentPos = currentCursorPosition()
        let newPoint = CGPoint(x: currentPos.x + dx, y: currentPos.y + dy)
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: newPoint,
            mouseButton: .left
        )
        event?.post(tap: .cgSessionEventTap)
    }

    func click(button: MouseButton, type: ClickType) {
        let pos = currentCursorPosition()
        let (downType, upType, cgButton) = eventTypes(for: button)

        switch type {
        case .down:
            postMouseEvent(downType, at: pos, button: cgButton)
        case .up:
            postMouseEvent(upType, at: pos, button: cgButton)
        case .click:
            postMouseEvent(downType, at: pos, button: cgButton)
            postMouseEvent(upType, at: pos, button: cgButton)
        }
    }

    func scroll(dx: Double, dy: Double) {
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(dy),
            wheel2: Int32(dx),
            wheel3: 0
        )
        event?.post(tap: .cgSessionEventTap)
    }

    private func currentCursorPosition() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    private func postMouseEvent(_ type: CGEventType, at point: CGPoint, button: CGMouseButton) {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        )
        event?.post(tap: .cgSessionEventTap)
    }

    private func eventTypes(for button: MouseButton) -> (down: CGEventType, up: CGEventType, button: CGMouseButton) {
        switch button {
        case .left:
            return (.leftMouseDown, .leftMouseUp, .left)
        case .right:
            return (.rightMouseDown, .rightMouseUp, .right)
        case .center:
            return (.otherMouseDown, .otherMouseUp, .center)
        }
    }
}
