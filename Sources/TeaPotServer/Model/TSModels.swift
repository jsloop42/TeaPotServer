//
//  TSResponse.swift
//  TeaPotServer
//
//  Created by jsloop on 20/09/19.
//

import Foundation

// MARK: Request

public struct TSRequestGeneric: Codable {
    var msg: String

    init(msg: String) {
        self.msg = msg
    }
}

// MARK: - Response

/// An ok response model used in `GET /`
public struct TSResponseOK: Codable {
    var status: Bool
    var data: String

    init(status: Bool, data: String) {
        self.status = status
        self.data = data
    }
}

/// Health response type used in `GET /health`
public struct TSResponseHealth: Codable {
    var status: Bool
    var data: TSHealth

    init(status: Bool, data: TSHealth) {
        self.status = status
        self.data = data
    }
}

/// Health response model
public struct TSHealth: Codable {
    var database: String
    var server: String
    var version: String

    init(database: String, server: String, version: String) {
        self.database = database
        self.server = server
        self.version = version
    }
}

/// An error response model
public struct TSResponseError: Error {
    var status: Bool
    var code: Int
    var msg: String

    init(status: Bool, code: Int, msg: String) {
        self.status = status
        self.code = code
        self.msg = msg
    }
}
