//
//  HTTPServer.swift
//  TeaPotServer
//
//  Created by jsloop on 20/08/19.
//

import Foundation
import NIO
import NIOSSL
import NIOHTTP1
import NIOHTTP2
import NIOFoundationCompat

public final class HTTP2Handler<Responder: HTTPResponder>: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart
    private let httpUtils = HTTPUtils.shared
    private let responder: Responder
    private var isKeepAlive: Bool = false
    private var request: HTTPServerRequest?

    public init(responder: Responder) {
        self.responder = responder
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        switch reqPart {
        case .head(let reqHead):
            print("req: ", reqHead)
            self.isKeepAlive = reqHead.isKeepAlive
            var contentLength: Int = 0  // The request body content length if present
            if let length = reqHead.headers["content-length"].first { contentLength = Int(length) ?? 0 }
            if contentLength > Const._10MB {  // Maximum request body size is limited to 10MB
                context.close(promise: nil)
            }
            var body: ByteBuffer? = nil
            if contentLength > 0 { body = context.channel.allocator.buffer(capacity: contentLength) }
            self.request = HTTPServerRequest(eventLoop: context.eventLoop, header: reqHead, bodyBuffer: body)
        case .body(let data):
            // Append new data to the body buffer
            data.withUnsafeReadableBytes { buff -> Void in
                self.request?.bodyBuffer?.writeBytes(buff)
            }
        case .end:
            guard let request = self.request else { return }
            let channel = context.channel
            DispatchQueue.global().async {
                let response: EventLoopFuture<HTTPServerResponse> = self.responder.respond(to: request).flatMapError { (err) -> EventLoopFuture<HTTPServerResponse> in
                    return request.eventLoop.makeSucceededFuture(HTTPServerResponse(status: .internalServerError, body: HTTPBody(text: Message.internalServerError)))
                }
                self.request = nil
                self.writeResponse(response, to: channel)
            }
        }
    }

    @discardableResult
    private func writeResponse(_ response: EventLoopFuture<HTTPServerResponse>, to channel: Channel) -> EventLoopFuture<Void> {
        let responded: EventLoopFuture<Void> = response.map { response -> Void in
            var header = response.header
            header.headers.remove(name: "content-length")
            if let body = response.body {
                let buffer = body.buffer
                header.headers.add(name: "content-length", value: String(buffer.writerIndex))
                if let mimeType = body.mimeType {
                    header.headers.remove(name: "content-type")
                    header.headers.add(name: "content-type", value: mimeType)
                    _ = self.httpUtils.writeHeader(header: header, to: channel)
                    _ = self.httpUtils.writeBody(buffer: buffer, to: channel)
                }
            } else {
                _ = self.httpUtils.writeHeader(header: header, to: channel)
            }
        }.flatMap { _ -> EventLoopFuture<Void> in
            return channel.writeAndFlush(HTTPServerResponsePart.end(nil))
        }
        responded.whenComplete { _ in
            if !self.isKeepAlive { _ = channel.close() }
        }
        return responded
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
}

public final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart
    private let httpUtils = HTTPUtils.shared

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        switch reqPart {
        case .head(let reqHead):
            print("req: ", reqHead)
            var headers = httpUtils.getHeaders(contentLength: 0)
            headers.add(name: "location", value: "https://[\(Const.host)]:\(Const.httpsPort)")  // TODO: change it to IPv4 mode
            let channel = context.channel
            DispatchQueue.global().async {
                self.httpUtils.sendHeader(status: .permanentRedirect, headers: headers, to: channel).flatMap({ (Void) -> EventLoopFuture<Void> in
                    return channel.writeAndFlush(HTTPServerResponsePart.end(nil))
                }).whenComplete({ _ in
                    _ = channel.close()
                })
            }
        case .body, .end:
            break
        }
    }
}

public class HTTPServer {

    public func start() {
        // TODO: load priv key from file
        // Load the private key
        let sslPrivateKey = try! NIOSSLPrivateKeySource.privateKey(NIOSSLPrivateKey(buffer: [Int8](Const.samplePKCS8PemPrivateKey.utf8CString),
                                                                                    format: .pem) { providePassword in
            providePassword("thisisagreatpassword".utf8)
        })
        // Load the certificate
        let sslCertificate = try! NIOSSLCertificateSource.certificate(NIOSSLCertificate(buffer: [Int8](Const.samplePemCert.utf8CString), format: .pem))

        // Set up the TLS configuration and set `applicationProtocols` to `NIOHTTP2SupportedALPNProtocols` which advertises the support of HTTP/2 to the clients
        let tlsConfiguration = TLSConfiguration.forServer(certificateChain: [sslCertificate], privateKey: sslPrivateKey,
                                                          applicationProtocols: NIOHTTP2SupportedALPNProtocols)
        // Configure the SSL context that is used by all SSL handlers.
        let sslContext = try! NIOSSLContext(configuration: tlsConfiguration)

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer { try! group.syncShutdownGracefully() }

        let bootstrapHTTP1 = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer({ channel in  // Set the handlers that are applied to the accepted Channels
                channel.pipeline.addHandler(BackPressureHandler()).flatMap({ _ in
                    // Add SSL handler because HTTP/2 is almost always spoken over TLS.
                    channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap({ (_) -> EventLoopFuture<Void> in
                        return channel.pipeline.addHandler(HTTPHandler())
                    }).flatMap({ () -> EventLoopFuture<Void> in
                        return channel.pipeline.addHandler(ErrorHandler())
                    })
                })
            })
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)  // Message grouping
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())  // Adjust the buffer size based on actual traffic

        let bootstrapHTTP2 = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)  // The number of TCP sockets waiting to be accepted for processing at a given time
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)  // Allow reuse of the IP address and port so that multiple threads can receive clients
            .childChannelInitializer({ channel in  // Set the handlers that are applied to the accepted Channels
                channel.pipeline.addHandler(try! NIOSSLServerHandler(context: sslContext)).flatMap { _ in
                    // Configure the HTTP/2 pipeline.
                    channel.configureHTTP2Pipeline(mode: .server) { streamChannel, streamID -> EventLoopFuture<Void> in
                        // For every HTTP/2 stream that the client opens, `HTTP2ToHTTP1ServerCodec` transforms the HTTP/2 frames to the HTTP/1 messages from the `NIOHTTP1` module.
                        streamChannel.pipeline.addHandler(HTTP2ToHTTP1ServerCodec(streamID: streamID)).flatMap { _ in
                            streamChannel.pipeline.addHandler(HTTP2Handler(responder: APIResponder()))  // Add the server
                        }.flatMap { () -> EventLoopFuture<Void> in
                            streamChannel.pipeline.addHandler(ErrorHandler())
                        }
                    }
                }.flatMap { (_: HTTP2StreamMultiplexer) in
                    return channel.pipeline.addHandler(ErrorHandler())
                }
            })
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)  // Message grouping
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())  // Adjust the buffer size based on actual traffic

        do {
            let channel1 = try bootstrapHTTP1.bind(host: Const.host, port: Const.httpPort).wait()
            let channel2 = try bootstrapHTTP2.bind(host: Const.host, port: Const.httpsPort).wait()
            Log?.info("Server started and listening on \(channel1.localAddress!)")
            Log?.info("Server started and listening on \(channel2.localAddress!)")
            try channel1.closeFuture.wait()
            try channel2.closeFuture.wait()
            Log?.info("Server closed")
        } catch let err {
            Log?.error("Error: \(err)")
        }
    }
}

public final class ErrorHandler: ChannelInboundHandler {
    public typealias InboundIn = Never

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        Log?.error("Server received error: \(error)")
        context.close(promise: nil)
    }
}
