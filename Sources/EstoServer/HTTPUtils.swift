//
//  HTTPUtils.swift
//  EstoServer
//
//  Created by jsloop on 23/08/19.
//

import Foundation
import NIO
import NIOHTTP1
import NIOHTTP2
import NIOFoundationCompat

public struct HTTPUtils {
    public static let shared = HTTPUtils()

    private init() {}

    public func getHeaders(contentLength: Int) -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: "content-length", value: String(contentLength))
        headers.add(name: "server", value: Const.serverName)
        return headers
    }

    // MARK: - Header

    public func writeHeader(header: HTTPResponseHead, to channel: Channel) -> EventLoopFuture<Void> {
        let part = HTTPServerResponsePart.head(header)
        return channel.write(part)
    }

    public func sendHeader(status: HTTPResponseStatus, headers: HTTPHeaders, to channel: Channel) -> EventLoopFuture<Void> {
        let head = HTTPResponseHead(version: .init(major: 2, minor: 0), status: status, headers: headers)
        let part = HTTPServerResponsePart.head(head)
        return channel.writeAndFlush(part)
    }

    // MARK: - Body

    public func writeBody(buffer: ByteBuffer, to channel: Channel) -> EventLoopFuture<Void> {
        let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
        return channel.write(part)
    }

    public func send(_ string: String, to channel: Channel) -> EventLoopFuture<Void> {
        if let data = string.data(using: .utf8) {
            return self.sendData(data, to: channel)
        }
        return sendErrorResponse("Internal server error", to: channel)
    }

    private func sendData(_ data: Data, to channel: Channel) -> EventLoopFuture<Void> {
        let headers = self.getHeaders(contentLength: data.count)
        _ = self.sendHeader(status: .ok, headers: headers, to: channel)
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
        return channel.writeAndFlush(part)
    }

    // MARK: - Error

    public func sendErrorResponse(_ msg: String, to channel: Channel) -> EventLoopFuture<Void> {
        var str = msg
        return self.sendData(Data(bytes: &str, count: str.count), to: channel)
    }
}
