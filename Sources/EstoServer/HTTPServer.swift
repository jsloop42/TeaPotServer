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

public class HTTPServer: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .end = self.unwrapInboundIn(data) else { return }
        // The event loop tick which represents real workloads in SwiftNIO, which will not re-entrantly write their response frames.
        context.eventLoop.execute {
            context.channel.getOption(HTTP2StreamChannelOptions.streamID).flatMap { (streamID) -> EventLoopFuture<Void> in
                let respBody = "hello world"
                var headers = HTTPHeaders()
                headers.add(name: "content-length", value: String(respBody.count))
                headers.add(name: "x-stream-id", value: String(Int(streamID)))
                headers.add(name: "x-server", value: Const.serverName)
                context.channel.write(self.wrapOutboundOut(HTTPServerResponsePart.head(HTTPResponseHead(version: .init(major: 2, minor: 0), status: .ok,
                                                                                                        headers: headers))), promise: nil)

                var buffer = context.channel.allocator.buffer(capacity: respBody.count)
                buffer.writeString(respBody)
                context.channel.write(self.wrapOutboundOut(HTTPServerResponsePart.body(.byteBuffer(buffer))), promise: nil)
                return context.channel.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end(nil)))
            }.whenComplete { _ in
                context.close(promise: nil)
            }
        }
    }

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
        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // Add SSL handler because HTTP/2 is almost always spoken over TLS.
                channel.pipeline.addHandler(try! NIOSSLServerHandler(context: sslContext)).flatMap {
                    // Configure the HTTP/2 pipeline.
                    channel.configureHTTP2Pipeline(mode: .server) { (streamChannel, streamID) -> EventLoopFuture<Void> in
                        // For every HTTP/2 stream that the client opens, put in the `HTTP2ToHTTP1ServerCodec` which transforms the HTTP/2 frames to the HTTP/1
                        // messages from the `NIOHTTP1` module.
                        streamChannel.pipeline.addHandler(HTTP2ToHTTP1ServerCodec(streamID: streamID)).flatMap { () -> EventLoopFuture<Void> in
                            streamChannel.pipeline.addHandler(HTTPServer())  // Add the server
                        }.flatMap { () -> EventLoopFuture<Void> in
                            streamChannel.pipeline.addHandler(ErrorHandler())
                        }
                    }
                }.flatMap { (_: HTTP2StreamMultiplexer) in
                    return channel.pipeline.addHandler(ErrorHandler())
                }
            }
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        do {
            let channel = try bootstrap.bind(host: Const.host, port: Const.port).wait()
            print("Server started and listening on \(channel.localAddress!)")
            try channel.closeFuture.wait()
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
