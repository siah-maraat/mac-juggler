import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import WebSocketKit
import Logging

final class WebSocketServer {
    private let host: String
    private let port: Int
    private let authManager: AuthManager
    private let cursorController: CursorController
    private let rateLimiter: RateLimiter
    private let logger: Logger
    private var eventLoopGroup: EventLoopGroup?

    init(
        host: String,
        port: Int,
        authManager: AuthManager,
        cursorController: CursorController,
        rateLimiter: RateLimiter,
        logger: Logger
    ) {
        self.host = host
        self.port = port
        self.authManager = authManager
        self.cursorController = cursorController
        self.rateLimiter = rateLimiter
        self.logger = logger
    }

    func start() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        self.eventLoopGroup = group

        let authManager = self.authManager
        let cursorController = self.cursorController
        let rateLimiter = self.rateLimiter
        let logger = self.logger

        let server = try ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                let remoteAddress = channel.remoteAddress?.description ?? "unknown"

                // Check local network
                if let address = channel.remoteAddress {
                    let ip: String?
                    switch address {
                    case .v4(let addr): ip = addr.host
                    case .v6(let addr): ip = addr.host
                    default: ip = nil
                    }
                    if let ip = ip, !NetworkGuard.isLocalNetwork(ip) {
                        logger.warning("Rejected non-local connection from \(ip)")
                        return channel.close()
                    }
                }

                let upgrader = NIOWebSocketServerUpgrader(
                    shouldUpgrade: { channel, head in
                        channel.eventLoop.makeSucceededFuture(HTTPHeaders())
                    },
                    upgradePipelineHandler: { channel, req in
                        let handler = RelayWebSocketHandler(
                            authManager: authManager,
                            cursorController: cursorController,
                            rateLimiter: rateLimiter,
                            logger: logger,
                            remoteAddress: remoteAddress
                        )
                        return channel.pipeline.addHandler(handler)
                    }
                )

                return channel.pipeline.configureHTTPServerPipeline(
                    withServerUpgrade: (
                        upgraders: [upgrader],
                        completionHandler: { context in }
                    )
                )
            }
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .bind(host: host, port: port)
            .wait()

        logger.info("WebSocket server started on \(host):\(port)")
        print("🚀 Trackpad Relay listening on ws://\(host):\(port)")

        try server.closeFuture.wait()
    }

    func stop() {
        try? eventLoopGroup?.syncShutdownGracefully()
    }
}

// WebSocket frame handler
private final class RelayWebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    private let authManager: AuthManager
    private let cursorController: CursorController
    private let rateLimiter: RateLimiter
    private let logger: Logger
    private let remoteAddress: String
    private var isAuthenticated = false
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        authManager: AuthManager,
        cursorController: CursorController,
        rateLimiter: RateLimiter,
        logger: Logger,
        remoteAddress: String
    ) {
        self.authManager = authManager
        self.cursorController = cursorController
        self.rateLimiter = rateLimiter
        self.logger = logger
        self.remoteAddress = remoteAddress
    }

    func handlerAdded(context: ChannelHandlerContext) {
        logger.info("Client connected from \(remoteAddress)")
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var frame = unwrapInboundIn(data)

        // Client frames are masked per RFC 6455 — unmask before reading
        if let maskKey = frame.maskKey {
            frame.data.webSocketUnmask(maskKey)
        }

        switch frame.opcode {
        case .text:
            var frameData = frame.data
            guard let text = frameData.readString(length: frameData.readableBytes) else { return }
            handleTextMessage(text, context: context)

        case .connectionClose:
            logger.info("Client disconnected: \(remoteAddress)")
            context.close(promise: nil)

        case .ping:
            let pongData = context.channel.allocator.buffer(capacity: 0)
            let pongFrame = WebSocketFrame(fin: true, opcode: .pong, data: pongData)
            context.writeAndFlush(wrapOutboundOut(pongFrame), promise: nil)

        default:
            break
        }
    }

    private func handleTextMessage(_ text: String, context: ChannelHandlerContext) {
        guard let data = text.data(using: .utf8),
              let message = try? decoder.decode(RelayMessage.self, from: data) else {
            sendResponse(.error("Invalid message format"), context: context)
            return
        }

        // Auth must be first message
        if !isAuthenticated {
            if case .auth(let token) = message {
                if authManager.validate(token) {
                    isAuthenticated = true
                    logger.info("Client authenticated: \(remoteAddress)")
                    sendResponse(.ok("Authenticated"), context: context)
                } else {
                    logger.warning("Auth failed from \(remoteAddress)")
                    sendResponse(.error("Invalid token"), context: context)
                    context.close(promise: nil)
                }
            } else {
                sendResponse(.error("Authentication required"), context: context)
                context.close(promise: nil)
            }
            return
        }

        // Rate limit
        if !rateLimiter.allow() {
            logger.warning("Rate limit exceeded for \(remoteAddress)")
            return
        }

        // Dispatch cursor commands
        switch message {
        case .auth:
            sendResponse(.ok("Already authenticated"), context: context)
        case .moveTo(let x, let y):
            cursorController.moveTo(x: x, y: y)
        case .moveBy(let dx, let dy):
            cursorController.moveBy(dx: dx, dy: dy)
        case .click(let button, let type):
            cursorController.click(button: button, type: type)
        case .scroll(let dx, let dy):
            cursorController.scroll(dx: dx, dy: dy)
        }
    }

    private func sendResponse(_ response: RelayResponse, context: ChannelHandlerContext) {
        guard let data = try? encoder.encode(response),
              let text = String(data: data, encoding: .utf8) else { return }

        var buffer = context.channel.allocator.buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        context.writeAndFlush(wrapOutboundOut(frame), promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("WebSocket error: \(error)")
        context.close(promise: nil)
    }
}
