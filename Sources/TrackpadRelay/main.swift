import ArgumentParser
import Foundation
import Logging

struct TrackpadRelay: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trackpad-relay",
        abstract: "WebSocket server that relays trackpad/cursor commands from iOS to macOS.",
        version: "0.1.1"
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
            fputs("⚠️  Waiting for Accessibility permission...\n", stderr)
            fputs("   The server will start but cursor control won't work until permission is granted.\n", stderr)
        }

        // Auth
        let authManager = AuthManager(token: token)
        fputs("🔑 Auth token: \(authManager.currentToken)\n", stderr)
        fputs("   Send this as the first WebSocket message:\n", stderr)
        fputs("   {\"type\":\"auth\",\"token\":\"\(authManager.currentToken)\"}\n\n", stderr)

        // Components
        let cursorController = CursorController()
        let rateLimiter = RateLimiter(maxPerSecond: 1000)

        // Signal handling for clean shutdown
        signal(SIGINT, { _ in
            fputs("\n🛑 Shutting down...\n", stderr)
            Darwin.exit(0)
        })
        signal(SIGTERM, { _ in
            fputs("\n🛑 Shutting down...\n", stderr)
            Darwin.exit(0)
        })

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
