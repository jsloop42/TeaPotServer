//
//  HTTPServer.swift
//  EstoServer
//
//  Created by jsloop on 20/08/19.
//

import Foundation
import NIO
import NIOSSL
import NIOHTTP1
import NIOHTTP2
import NIOFoundationCompat

public struct StreamContext {
    public var streamID: Int

    init(streamID: Int) {
        self.streamID = streamID
    }
}

public class HTTP2Handler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart
    private var router: Router = Router()

    public func getHeaders(contentLength: Int, context: StreamContext) -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: "content-length", value: String(contentLength))
        headers.add(name: "x-stream-id", value: String(context.streamID))
        headers.add(name: "server", value: Const.serverName)
        return headers
    }

    public func sendHeader(status: HTTPResponseStatus, headers: HTTPHeaders, to channel: Channel, context: StreamContext) -> EventLoopFuture<Void> {
        let head = HTTPResponseHead(version: .init(major: 2, minor: 0), status: status, headers: headers)
        let part = HTTPServerResponsePart.head(head)
        return channel.writeAndFlush(part)
    }

    private func sendData(_ data: Data, to channel: Channel, context: StreamContext) -> EventLoopFuture<Void> {
        let headers = self.getHeaders(contentLength: data.count, context: context)
        _ = self.sendHeader(status: .ok, headers: headers, to: channel, context: context)
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
        return channel.writeAndFlush(part)
    }

    public func send(_ string: String, to channel: Channel, context: StreamContext) -> EventLoopFuture<Void> {
        if let data = string.data(using: .utf8) {
            return self.sendData(data, to: channel, context: context)
        }
        return sendErrorResponse("Internal server error", to: channel, context: context)
    }

    public func handleError(_ error: Error, in channel: Channel, context: StreamContext) {
        print("Error: \(error)")
    }

    public func sendErrorResponse(_ msg: String, to channel: Channel, context: StreamContext) -> EventLoopFuture<Void> {
        var str = msg
        return self.sendData(Data(bytes: &str, count: str.count), to: channel, context: context)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        switch reqPart {
        case .head(let header):
            print("req: ", header)
            // The event loop tick which represents real workloads in SwiftNIO, which will not re-entrantly write their response frames.
            context.eventLoop.execute {
                context.channel.getOption(HTTP2StreamChannelOptions.streamID).flatMap { streamID -> EventLoopFuture<Void> in
                    return self.send("hello world new ok", to: context.channel, context: StreamContext(streamID: Int(streamID)))
                }.whenComplete({ _ in
                    _ = context.channel.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end(nil)))
                    context.close(promise: nil)
                })
            }
        case .body, .end:
            break
        }
    }
}

public class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    public func getHeaders(contentLength: Int, context: StreamContext) -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: "content-length", value: String(contentLength))
        headers.add(name: "x-stream-id", value: String(context.streamID))
        headers.add(name: "server", value: Const.serverName)
        headers.add(name: "location", value: "https://\(Const.host):\(Const.httpsPort)")
        return headers
    }

    public func sendHeader(status: HTTPResponseStatus, headers: HTTPHeaders, to channel: Channel, context: StreamContext) -> EventLoopFuture<Void> {
        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: status, headers: headers)
        let part = HTTPServerResponsePart.head(head)
        return channel.writeAndFlush(part)
    }

    private func sendData(_ data: Data, to channel: Channel, context: StreamContext) -> EventLoopFuture<Void> {
        let headers = self.getHeaders(contentLength: data.count, context: context)
        _ = self.sendHeader(status: .permanentRedirect, headers: headers, to: channel, context: context)
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
        return channel.writeAndFlush(part)
    }

    public func send(_ string: String, to channel: Channel, context: StreamContext) -> EventLoopFuture<Void> {
        if let data = string.data(using: .utf8) {
            return self.sendData(data, to: channel, context: context)
        }
        return sendErrorResponse("Internal server error", to: channel, context: context)
    }

    public func handleError(_ error: Error, in channel: Channel, context: StreamContext) {
        print("Error: \(error)")
    }

    public func sendErrorResponse(_ msg: String, to channel: Channel, context: StreamContext) -> EventLoopFuture<Void> {
        var str = msg
        return self.sendData(Data(bytes: &str, count: str.count), to: channel, context: context)
    }


    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        switch reqPart {
        case .head(let header):
            print("req: ", header)
            return self.send("hello world new ok", to: context.channel, context: StreamContext(streamID: Int(1))).whenComplete({ _ in
                _ = context.channel.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end(nil)))
                context.close(promise: nil)
            })
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
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer({ channel in
                channel.pipeline.addHandler(BackPressureHandler()).flatMap({ _ in
                    // Add SSL handler because HTTP/2 is almost always spoken over TLS.
                    channel.pipeline.configureHTTPServerPipeline().flatMap({ () -> EventLoopFuture<Void> in
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
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer({ channel in
                channel.pipeline.addHandler(try! NIOSSLServerHandler(context: sslContext)).flatMap { _ in
                    // Configure the HTTP/2 pipeline.
                    channel.configureHTTP2Pipeline(mode: .server) { streamChannel, streamID -> EventLoopFuture<Void> in
                        // For every HTTP/2 stream that the client opens, put in the `HTTP2ToHTTP1ServerCodec` which transforms the HTTP/2 frames to the HTTP/1
                        // messages from the `NIOHTTP1` module.
                        streamChannel.pipeline.addHandler(HTTP2ToHTTP1ServerCodec(streamID: streamID)).flatMap { _ in
                            streamChannel.pipeline.addHandler(HTTP2Handler())  // Add the server
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
            print("Server started and listening on \(channel1.localAddress!)")
            print("Server started and listening on \(channel2.localAddress!)")
            try channel1.closeFuture.wait()
            try channel2.closeFuture.wait()
            print("Server closed")
        } catch let err {
            print("Error: \(err)")
        }
    }
}

final class ErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("Server received error: \(error)")
        context.close(promise: nil)
    }
}
