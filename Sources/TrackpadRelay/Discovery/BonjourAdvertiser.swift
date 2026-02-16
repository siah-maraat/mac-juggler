import Foundation
import Network

final class BonjourAdvertiser {
    private var listener: NWListener?
    private let port: UInt16

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        let parameters = NWParameters()
        let listener = try? NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

        listener?.service = NWListener.Service(
            name: Host.current().localizedName ?? "Mac",
            type: "_trackpadrelay._tcp"
        )

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("📡 Bonjour: advertising _trackpadrelay._tcp on port \(self.port)")
            case .failed(let error):
                print("⚠️  Bonjour failed: \(error)")
            default:
                break
            }
        }

        // We don't actually accept connections here — the WebSocket server handles that.
        // This listener is only for Bonjour advertisement.
        listener?.newConnectionHandler = { connection in
            connection.cancel()
        }

        listener?.start(queue: .global())
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}
