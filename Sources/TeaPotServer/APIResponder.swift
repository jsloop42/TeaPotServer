//
//  APIResponder.swift
//  TeaPotServer
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
                do {
                    Log?.debug("Request received: GET /")
                    let resp = try self.constructOKResponse()
                    return request.eventLoop.makeSucceededFuture(HTTPServerResponse(status: .ok, body: resp))
                } catch let err {
                    Log?.error("Error sending GET / response: \(err)")
                    return self.sendError500Response(request: request)
                }
            case "/health":
                do {
                    Log?.debug("Request received: GET /health")
                    let body = try self.constructHealthResponse()
                    return request.eventLoop.makeSucceededFuture(HTTPServerResponse(status: .ok, body: body))
                } catch let err {
                    Log?.error("Error sending GET /health response: \(err)")
                    return self.sendError500Response(request: request)
                }
            default:
                return self.sendError404Response(request: request)
            }
        case .POST:
            switch header.uri {
            case "/reverse":
                do {
                    if var reqBody = request.body {
                        var body = HTTPBody(data: reqBody.data, mimeType: MimeType.json.rawValue)
                        let echo = try body.decodeJSON(entity: TSRequestGeneric.self)
                        let resp = TSResponseOK(status: true, data: String(echo.msg.reversed()))
                        let respBody = try HTTPBody(entity: resp, prettyPrint: true)
                        return request.eventLoop.makeSucceededFuture(HTTPServerResponse(status: .ok, body: respBody))
                    }
                } catch let err {
                    Log?.error("Error sending POST /reverse response: \(err)")
                    return self.sendError500Response(request: request)
                }
            default:
                return self.sendError404Response(request: request)
            }
        case .PUT:
            return self.sendError404Response(request: request)
        case .DELETE:
            return self.sendError404Response(request: request)
        default:
            return self.sendError404Response(request: request)
        }
        let body = HTTPBody(text: "Route not found")
        return request.eventLoop.makeSucceededFuture(HTTPServerResponse(status: .notFound, body: body))
    }

    public func constructOKResponse() throws -> HTTPBody {
        return try HTTPBody(entity: TSResponseOK(status: true, data: "ok"), prettyPrint: true)
    }

    public func constructHealthResponse() throws -> HTTPBody {
        return try HTTPBody(entity: TSResponseHealth(status: true, data: TSHealth(database: "", server: Const.serverName, version: Const.serverVersion)),
                            prettyPrint: true)
    }

    public func constructErrorResponse(status: HTTPResponseStatus, msg: String) -> HTTPServerResponse {
        let body = "{\"status\": false, \"code\": \(status.code), \"msg\": \"\(msg)\"}"
        return HTTPServerResponse(status: .internalServerError, body: HTTPBody(text: body))
    }

    /// Sends an internal server error
    public func sendError500Response(request: HTTPServerRequest) -> EventLoopFuture<HTTPServerResponse> {
        let status = HTTPResponseStatus.internalServerError
        return request.eventLoop.makeSucceededFuture(self.constructErrorResponse(status: status, msg: status.reasonPhrase))
    }

    /// Sends not found error
    public func sendError404Response(request: HTTPServerRequest) -> EventLoopFuture<HTTPServerResponse> {
        let status = HTTPResponseStatus.notFound
        return request.eventLoop.makeSucceededFuture(self.constructErrorResponse(status: status, msg: status.reasonPhrase))
    }
}
