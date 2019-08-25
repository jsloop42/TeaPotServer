//
//  FileIO.swift
//  EstoServer
//
//  Created by jsloop on 24/08/19.
//

import Foundation
import Dispatch

/// File open mode
public enum FileIOMode {
    case read
    case write
    case append
}

/// Used for working with file input/output.
public class FileIO {
    public let fileManager: FileManager = FileManager.default
    public var fileHandle: FileHandle?
    public var fileUrl: URL?
    private var dispatchQueue: DispatchQueue = DispatchQueue(label: "com.estoapps.estoserver.fileio")
    private var isRotatingFile = false
    private var logQueue: [String] = []

    /// Checks if the file exists at the given URL.
    public func isFileExists(at fileUrl: URL) -> Bool {
        return self.fileManager.fileExists(atPath: fileUrl.path)
    }

    /// Checks if the directory exists at the given URL.
    public func isDirectoryExists(at dirURL: URL) -> Bool {
        var isDir: ObjCBool = false
        if self.fileManager.fileExists(atPath: dirURL.path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        return false
    }

    /// Create a file at the given file url irrespective of whether the file exists or not. If the file exists at the file url, this will clear its contents.
    public func createFile(_ fileUrl: URL) {
        self.fileManager.createFile(atPath: fileUrl.path, contents: nil, attributes: nil)
    }

    /// Creates a file at the given file URL if it does not exists already.
    public func createFileIfNotExists(_ fileUrl: URL) {
        if !self.isFileExists(at: fileUrl) {
            self.createFile(fileUrl)
        }
    }

    /// Open an existing file with the given mode, which can be for reading, writing or for appending.
    public func openFile(fileUrl: URL, mode: FileIOMode) {
        switch mode {
        case .read:
            self.fileHandle = FileHandle(forReadingAtPath: fileUrl.path)
        case .write:
            self.fileHandle = FileHandle(forWritingAtPath: fileUrl.path)
        case .append:
            self.fileHandle = FileHandle(forUpdatingAtPath: fileUrl.path)
        }
        self.fileUrl = fileUrl
    }

    public func getFileAttributes(for fileUrl: URL) -> [FileAttributeKey: Any] {
        do {
            return try self.fileManager.attributesOfItem(atPath: fileUrl.path)
        } catch let err {
            print("Error getting file attributes: \(err.localizedDescription)")
        }
        return [:]
    }

    /// Appends the given string to the file and invokes the completion handler if specified. This method writes to the file serially in a background thread.
    public func append(string: String, completion: ((Bool) -> Void)? = nil) {
        if !self.isRotatingFile {
            let attrib = self.getFileAttributes(for: self.fileUrl!)
            let size: Double = attrib[.size] as? Double ?? 0.0
            if size >= Const.maxLogFileSize {  // Do file rotation
                self.isRotatingFile = true
                self.close()
                do {
                    try self.fileManager.moveItem(at: self.fileUrl!, to: URL(fileURLWithPath: "/var/tmp/estoserver/server.2.log"))
                } catch let err {
                    print("Error moving file: \(err.localizedDescription)")
                }
                let url = URL(fileURLWithPath: "/var/tmp/estoserver/server.log")
                self.createFileIfNotExists(url)
                self.openFile(fileUrl: url, mode: .append)
            }
            if !self.isRotatingFile {
                if let fileHandle = self.fileHandle {
                    self.appendToFile(string: string, fileHandle: fileHandle, completion: { if let cb = completion { cb(true) } })
                }
            } else {
                self.logQueue.append(string)
            }
            self.processLogQueue()
        } else {
            self.logQueue.append(string)
        }
    }

    private func appendToFile(string: String, fileHandle: FileHandle, completion: () -> Void) {
        self.dispatchQueue.sync {
            fileHandle.seekToEndOfFile()
            if let data = string.data(using: .utf8) {
                fileHandle.write(data)
                completion()
            }
        }
    }

    private func processLogQueue() {
        if self.isRotatingFile {
            if self.logQueue.isEmpty {
                self.isRotatingFile = false  // Reset file rotating status until all log messages in the log queue are processed. Else there will be writing inconsistency.
            } else {
                let logMsg = self.logQueue.removeFirst()
                if let fileHandle = self.fileHandle {
                    self.appendToFile(string: logMsg, fileHandle: fileHandle) { self.processLogQueue() }
                }
            }
        }
    }

    public func delete(_ fileUrl: URL) {
        do { try self.fileManager.removeItem(at: fileUrl) } catch let err { print("Error deleting file: \(err.localizedDescription)") }

    }

    /// Reclaim any held resources.
    public func close() {
        self.fileHandle?.closeFile()
    }
}
