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
public struct FileIO {
    public let fileManager: FileManager = FileManager.default
    public var fileHandle: FileHandle?
    private var dispatchQueue: DispatchQueue = DispatchQueue(label: "com.estoapps.estoserver.fileio")

    /// Checks if the file exists at the given URL.
    public func isFileExists(at fileUrl: URL) -> Bool {
        do {
            return try fileUrl.checkResourceIsReachable()
        } catch let err {
            Log?.error("Error checking file exists \(err)")
        }
        return false
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
    public mutating func openFile(fileUrl: URL, mode: FileIOMode) {
        switch mode {
        case .read:
            self.fileHandle = FileHandle(forReadingAtPath: fileUrl.path)
        case .write:
            self.fileHandle = FileHandle(forWritingAtPath: fileUrl.path)
        case .append:
            self.fileHandle = FileHandle(forUpdatingAtPath: fileUrl.path)
        }
    }

    /// Appends the given string to the file and invokes the completion handler if specified. This method writes to the file serially in a background thread.
    public func append(string: String, completion: ((Bool) -> Void)? = nil) {
        self.dispatchQueue.sync {
            if let handle = self.fileHandle, let data = string.data(using: .utf8) {
                handle.seekToEndOfFile()
                handle.write(data)
                if let cb = completion { cb(true) }
            } else {
                if let cb = completion { cb(false) }
            }
        }
    }

    /// Reclaim any held resources.
    public func close() {
        self.fileHandle?.closeFile()
    }
}
