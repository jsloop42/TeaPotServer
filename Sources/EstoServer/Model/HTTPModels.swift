//
//  HTTPServerRequest.swift
//  EstoServer
//
//  Created by jsloop on 20/08/19.
//

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat

/// Represents a `HTTPServerRequest` object.
public class HTTPServerRequest {
    public let eventLoop: EventLoop
    public let header: HTTPRequestHead
    public var bodyBuffer: ByteBuffer?

    public lazy var body: HTTPBody? = {
        guard let buffer = self.bodyBuffer else { return nil }
        return HTTPBody(buffer: buffer)
    }()

    public init(eventLoop: EventLoop, header: HTTPRequestHead, bodyBuffer: ByteBuffer?) {
        self.eventLoop = eventLoop
        self.header = header
        self.bodyBuffer = bodyBuffer
    }
}

public struct HTTPServerResponse {
    public let header: HTTPResponseHead
    public let body: HTTPBody?

    public init(status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), body: HTTPBody?) {
        self.header = HTTPResponseHead(version: .init(major: 2, minor: 0), status: status, headers: headers)
        self.body = body
    }
}

public struct HTTPBody: ExpressibleByStringLiteral {
    private static let allocator = ByteBufferAllocator()
    let buffer: ByteBuffer
    public let mimeType: String?
    public lazy var data: Data = {
        return self.buffer.withUnsafeReadableBytes({ buff -> Data in
            let buffer = buff.bindMemory(to: UInt8.self)
            return Data(buffer: buffer)
        })
    }()

    public init(buffer: ByteBuffer, mimeType: String? = nil) {
        self.buffer = buffer
        self.mimeType = mimeType
    }

    public init(text: String) {
        var buffer = HTTPBody.allocator.buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        self.buffer = buffer
        self.mimeType = MimeType.plainText.rawValue
    }

    public init(data: Data, mimeType: String? = nil) {
        var buffer = HTTPBody.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        self.buffer = buffer
        self.mimeType = mimeType
    }

    public init<Entity: Encodable>(entity: Entity, prettyPrint: Bool = false) throws {
        let encoder = JSONEncoder()
        if prettyPrint { encoder.outputFormatting = .prettyPrinted }
        let data = try encoder.encode(entity)
        self.init(data: data, mimeType: MimeType.json.rawValue)
    }

    public init(stringLiteral value: String) {
        self.init(text: value)
    }

    public mutating func decodeJSON<Entity: Decodable>(entity: Entity.Type) throws -> Entity {
        return try JSONDecoder().decode(entity, from: self.data)
    }
}

public protocol HTTPResponder {
    func respond(to request: HTTPServerRequest) -> EventLoopFuture<HTTPServerResponse>
}
