import ArgumentParser
import Foundation
import Logging

struct TrackpadRelay: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trackpad-relay",
        abstract: "WebSocket server that relays trackpad/cursor commands from iOS to macOS.",
        version: "0.1.0"
    )

    @Option(name: .shortAndLong, help: "Port to listen on.")
    var port: Int = 8080

    @Option(name: .shortAndLong, help: "Authentication token. Generated automatically if not provided.")
    var token: String?

    @Flag(name: .shortAndLong, help: "Enable verbose logging.")
    var verbose: Bool = false

    func run() throws {
        // Logger
        var logger = Logger(label: "trackpad-relay")
        logger.logLevel = verbose ? .debug : .info

        // Check accessibility permission
        if !AccessibilityCheck.ensurePermission() {
            print("⚠️  Waiting for Accessibility permission...")
            print("   The server will start but cursor control won't work until permission is granted.")
        }

        // Auth
        let authManager = AuthManager(token: token)
        print("🔑 Auth token: \(authManager.currentToken)")
        print("   Send this as the first WebSocket message:")
        print("   {\"type\":\"auth\",\"token\":\"\(authManager.currentToken)\"}")
        print("")

        // Components
        let cursorController = CursorController()
        let rateLimiter = RateLimiter(maxPerSecond: 1000)

        // Bonjour
        let bonjour = BonjourAdvertiser(port: UInt16(port))
        bonjour.start()

        // Signal handling for clean shutdown
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN) // Ignore default handler
        signalSource.setEventHandler {
            print("\n🛑 Shutting down...")
            bonjour.stop()
            TrackpadRelay.exit()
        }
        signalSource.resume()

        // Start WebSocket server (blocks)
        let server = WebSocketServer(
            host: "0.0.0.0",
            port: port,
            authManager: authManager,
            cursorController: cursorController,
            rateLimiter: rateLimiter,
            logger: logger
        )

        try server.start()
    }
}

TrackpadRelay.main()
