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
    private var authenticatedChannels: Set<ObjectIdentifier> = []

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

        let upgrader = NIOWebSocketServerUpgrader(
            shouldUpgrade: { channel, head in
                channel.eventLoop.makeSucceededFuture(HTTPHeaders())
            },
            upgradePipelineHandler: { channel, req in
                let wsHandler = WebSocketHandler(
                    authManager: self.authManager,
                    cursorController: self.cursorController,
                    rateLimiter: self.rateLimiter,
                    logger: self.logger,
                    remoteAddress: channel.remoteAddress?.description ?? "unknown"
                )
                return channel.pipeline.addHandler(wsHandler)
            }
        )

        let bootstrap = ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                let httpHandler = HTTPByteBufferResponsePartHandler()
                return channel.pipeline.configureHTTPServerPipeline(
                    withServerUpgrade: (
                        upgraders: [upgrader],
                        completionHandler: { context in }
                    )
                ).flatMap {
                    channel.pipeline.addHandler(httpHandler)
                }
            }
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let channel = try bootstrap.bind(host: host, port: port).wait()
        logger.info("WebSocket server started on \(host):\(port)")
        print("🚀 Trackpad Relay listening on ws://\(host):\(port)")

        try channel.closeFuture.wait()
    }

    func stop() {
        try? eventLoopGroup?.syncShutdownGracefully()
    }
}

// Simple HTTP handler that responds to non-WebSocket requests
private final class HTTPByteBufferResponsePartHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        guard case .head = part else { return }

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain")
        let body = "Trackpad Relay is running. Connect via WebSocket.\n"

        let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
        buffer.writeString(body)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}

// WebSocket frame handler
private final class WebSocketHandler: ChannelInboundHandler {
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

    func channelActive(context: ChannelHandlerContext) {
        // Check if connection is from local network
        if let address = context.channel.remoteAddress,
           let ip = extractIP(from: address) {
            if !NetworkGuard.isLocalNetwork(ip) {
                logger.warning("Rejected non-local connection from \(ip)")
                context.close(promise: nil)
                return
            }
        }

        logger.info("Client connected from \(remoteAddress)")
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)

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
            return // silently drop
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

    private func extractIP(from address: SocketAddress) -> String? {
        switch address {
        case .v4(let addr):
            return addr.host
        case .v6(let addr):
            return addr.host
        default:
            return nil
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("WebSocket error: \(error)")
        context.close(promise: nil)
    }
}
