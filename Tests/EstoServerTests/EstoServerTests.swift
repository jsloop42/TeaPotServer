import XCTest
import class Foundation.Bundle
import Logging

final class EstoServerTests: XCTestCase {
    private var isLoggerInitialized = false
    private lazy var log: LoggingService = {
        if !self.isLoggerInitialized {
            _ = LoggingService.init(level: .debug)
        }
        return Log!
    }()

    func testFileIO() {
        var fileIO = FileIO()
        //let name = String("\(UUID())".prefix(8)).lowercased()
        //let fileUrl = URL(fileURLWithPath: "/var/tmp/estoserver/\(name)")
//        XCTAssertFalse(fileIO.isFileExists(at: fileUrl))
//        fileIO.createFileIfNotExists(fileUrl)
//        XCTAssertTrue(fileIO.isFileExists(at: fileUrl))
        fileIO.createFile(URL(fileURLWithPath: "/var/tmp/estoserver/testfile"))
    }

    static var allTests = [
        ("testFileIO", testFileIO),
    ]
}
