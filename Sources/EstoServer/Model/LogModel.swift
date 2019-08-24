//
//  LogModel.swift
//  EstoServer
//
//  Created by jsloop on 24/08/19.
//

import Foundation
import NIOHTTP1

public struct LogModel {
    public var dateCreated: Date = Date()
    public var requestData: LogRequestData?
    public var correlationId: String
    public var message: String
    public var file: String?
    public var function: String?
    public var line: UInt?

    init(message: String, correlationId: String, header: HTTPRequestHead) {
        self.message = message
        self.correlationId = correlationId
        self.requestData = LogRequestData(with: header)
    }

    init(message: String, correlationId: String, requestData: LogRequestData) {
        self.message = message
        self.correlationId = correlationId
        self.requestData = requestData
    }

    init(message: String, correlationId: String) {
        self.message = message
        self.correlationId = correlationId
    }
}

public struct LogRequestData {
    public var method: String
    public var uri: String
    public var version: String
    public var host: String
    public var userAgent: String
    public var acceptLanguage: String
    public var referrer: String
    public var ip: String

    init(method: String, uri: String, version: String, host: String, userAgent: String, acceptLanguage: String, referrer: String, ip: String) {
        self.method = method
        self.uri = uri
        self.version = version
        self.host = host
        self.userAgent = userAgent
        self.acceptLanguage = acceptLanguage
        self.referrer = referrer
        self.ip = ip
    }

    init(with head: HTTPRequestHead) {
        self.method = head.method.rawValue
        self.uri = head.uri
        self.version = head.version.description
        self.host = head.headers["host"].first ?? ""
        self.userAgent = head.headers["user-agent"].first ?? ""
        self.acceptLanguage = head.headers["accept-language"].first ?? ""
        self.referrer = head.headers["referrer"].first ?? ""
        self.ip = head.headers["ip"].first ?? ""
    }
}


