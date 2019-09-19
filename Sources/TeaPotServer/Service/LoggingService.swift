//
//  LoggingService.swift
//  TeaPotServer
//
//  Created by jsloop on 24/08/19.
//

import Foundation
import Logging

public var Log: LoggingService?

public struct LoggingService {
    private var muxHandler: MultiplexLogHandler
    public var level: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]

    init(level: Logger.Level, handlers: [LogHandler]) {
        self.level = level
        self.muxHandler = MultiplexLogHandler(handlers)
        Log = self
    }

    init(level: Logger.Level) {
        self.init(level: level, handlers: [PlainTextFileLogHandler(logLevel: level),
                                           StreamLogHandler.standardOutput(label: Const.serverName)])
    }

    init() {
        self.init(level: .info)
    }

    public mutating func setMetadata(meta: [String: CustomStringConvertible]) {
        meta.forEach { arg in
            let (k, v) = arg
            self.muxHandler[metadataKey: k] = Logger.MetadataValue(stringLiteral: v.description)
        }
        self.metadata = self.muxHandler.metadata
    }

    public mutating func setMetadata(key: String, value: CustomStringConvertible) {
        self.muxHandler[metadataKey: key] = Logger.MetadataValue(stringLiteral: value.description)
        self.metadata = self.muxHandler.metadata
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    file: String, function: String, line: UInt) {
        self.muxHandler.log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    public func info(_ message: Logger.Message, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: self.level, message: message, metadata: self.metadata, file: file, function: function, line: line)
    }

    public func debug(_ message: Logger.Message, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: self.level, message: message, metadata: self.metadata, file: file, function: function, line: line)
    }

    public func error(_ message: Logger.Message, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: self.level, message: message, metadata: self.metadata, file: file, function: function, line: line)
    }
}

public struct PlainTextFileLogHandler: LogHandler {
    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]
    public var logFileUrl: URL
    private var fileIO: FileIO = FileIO()

    public init(logFileUrl: URL, logLevel: Logger.Level) {
        self.logLevel = logLevel
        self.logFileUrl = logFileUrl
        self.bootstrap()
    }

    public init(logFileUrl: URL) {
        self.logFileUrl = logFileUrl
    }

    public init(logLevel: Logger.Level) {
        self.init(logFileUrl: URL(fileURLWithPath: Const.logFilePath), logLevel: logLevel)
    }

    private mutating func bootstrap() {
        self.fileIO.createFileIfNotExists(self.logFileUrl)
        self.fileIO.openFile(fileUrl: self.logFileUrl, mode: .append)
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        let file: String = {
            let fileComp = (file as NSString).lastPathComponent.split(separator: ".")
            if fileComp.count >= 2 { return "\(fileComp[0]).\(fileComp[1])" }
            return ""
        }()
        let logMsg: String
        if let meta = metadata, meta.count > 0 {
            logMsg = "\(Utils.shared.localTimeToString()) [\(level)] \(file) \(function):\(line) \(message) \(meta.description)"
        } else {
            logMsg = "\(Utils.shared.localTimeToString()) [\(level)] \(file) \(function):\(line) \(message)"
        }
        self.fileIO.append(string: logMsg.appending("\n"))
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[key]
        }
        set(newValue) {
            self.metadata[key] = newValue
        }
    }
}

public struct FoundationDBFileLogHandler: LogHandler {
    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]
    public var dbUrl: String

    public init(dbUrl: String, logLevel: Logger.Level) {
        self.logLevel = logLevel
        self.dbUrl = dbUrl
    }

    public init(dbUrl: String) {
        self.dbUrl = dbUrl
    }

    public init(logLevel: Logger.Level) {
        self.init(dbUrl: Const.fsDBURL, logLevel: logLevel)
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        let file: String = {
            let fileComp = (file as NSString).lastPathComponent.split(separator: ".")
            if fileComp.count >= 2 { return "\(fileComp[0]).\(fileComp[1])" }
            return ""
        }()
        var logData = LogModel(message: message.description, correlationId: "")
        logData.file = file
        logData.function = function
        logData.line = line
        if let meta = metadata {
            if let corrID = meta["correlationid"] {
                logData.correlationId = corrID.description
            }
            let req = LogRequestData(method: meta["method"]?.description ?? "", uri: meta["uri"]?.description ?? "",
                                     version: meta["version"]?.description ?? "", host: meta["host"]?.description ?? "",
                                     userAgent: meta["userAgent"]?.description ?? "", acceptLanguage: meta["acceptLanguage"]?.description ?? "",
                                     referrer: meta["referrer"]?.description ?? "", ip: meta["ip"]?.description ?? "")
            logData.requestData = req
        }
        // TODO: write to fsdb
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[key]
        }
        set(newValue) {
            self.metadata[key] = newValue
        }
    }
}
