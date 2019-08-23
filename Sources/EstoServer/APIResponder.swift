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

struct APIResponder: HTTPResponder {
    func respond(to request: HTTPServerRequest) -> EventLoopFuture<HTTPServerResponse> {
        let body = HTTPBody(text: "hello world")
        return request.eventLoop.makeSucceededFuture(HTTPServerResponse(status: .ok, body: body))
    }
}
