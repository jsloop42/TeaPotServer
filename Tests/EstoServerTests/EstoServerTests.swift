import XCTest
import class Foundation.Bundle
import Logging
import EstoServer

final class EstoServerTests: XCTestCase {
    private var isLoggerInitialized = false
    private lazy var log: LoggingService = {
        if !self.isLoggerInitialized {
            _ = LoggingService.init(level: .debug)
        }
        return Log!
    }()
    private let http = HTTPClient()

    func testFileIO() {
        let fileIO = FileIO()
        let name = String("\(UUID())".prefix(8)).lowercased()
        let fileUrl = URL(fileURLWithPath: "/var/tmp/estoserver/\(name)")
        XCTAssertFalse(fileIO.isFileExists(at: fileUrl))
        fileIO.createFileIfNotExists(fileUrl)
        XCTAssertTrue(fileIO.isFileExists(at: fileUrl))
        fileIO.delete(fileUrl)
        XCTAssertFalse(fileIO.isFileExists(at: fileUrl))
    }

    func testGetRoot() {
        let expectation = XCTestExpectation(description: "GET /")
        if let url = URL(string: "https://[::1]:4430/") {
            self.http.get(url) { data in
                if let aData = data {
                    let str = String(data: aData, encoding: .utf8)
                    print("GET / \(String(describing: str))")
                    expectation.fulfill()
                }
            }
            wait(for: [expectation], timeout: 10)
        } else {
            XCTAssert(false, "Constructing URL failed")
        }
    }

    static var allTests = [
        ("testFileIO", testFileIO),
        ("testGetRoot", testGetRoot),
    ]
}
