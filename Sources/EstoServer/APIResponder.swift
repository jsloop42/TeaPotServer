//
//  APIResponder.swift
//  EstoServer
//
//  Created by jsloop on 23/08/19.
//

import Foundation
import NIO
import NIOHTTP1
import NIOHTTP2
import NIOFoundationCompat

public struct APIResponder: HTTPResponder {
    public func respond(to request: HTTPServerRequest) -> EventLoopFuture<HTTPServerResponse> {
        let header = request.header
        switch header.method {
        case .GET:
            switch header.uri {
            case "/":
                Log?.debug("Request received: GET /")
                let body = HTTPBody(text: "GET / -> hello world")
                return request.eventLoop.makeSucceededFuture(HTTPServerResponse(status: .ok, body: body))
            case "/health":
                Log?.debug("Request received: GET /health")
                let body = HTTPBody(text: "GET /health -> ok")
                return request.eventLoop.makeSucceededFuture(HTTPServerResponse(status: .ok, body: body))
            default:
                break
            }
            break
        case .POST:
            break
        case .PUT:
            break
        case .DELETE:
            break
        default:
            break
        }
        let body = HTTPBody(text: "Route not found")
        return request.eventLoop.makeSucceededFuture(HTTPServerResponse(status: .notFound, body: body))
    }
}
