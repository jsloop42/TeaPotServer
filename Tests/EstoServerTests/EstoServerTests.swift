import XCTest
import class Foundation.Bundle
import Logging
import EstoServer

class State {
    public static let shared = State()
    public var isServerRunning = false
    public var server: HTTPServer = HTTPServer()

    deinit {
        
    }

    func startServer() -> State {
        DispatchQueue.global().async {
            if !self.isServerRunning {
                self.isServerRunning = true
                self.server.start()
            }
        }
        return self
    }
}

final class EstoServerTests: XCTestCase {
    private var isLoggerInitialized = false
    private lazy var log: LoggingService = {
        if !self.isLoggerInitialized {
            _ = LoggingService.init(level: .debug)
        }
        return Log!
    }()
    private let http = HTTPClient()
    private let state: State = State.shared.startServer()

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
        XCTAssertTrue(State.shared.isServerRunning)
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

    func testDateFormatting() {
        let date = Date(msSinceEpoch: 1546281000000)
        let dateStr = Utils.shared.dateToString(for: date, withFormat: DateFormat.dd_MMM_yyyy_HH_mm_ss.rawValue)
        XCTAssertEqual(dateStr, "01-Jan-2019-00:00:00")
    }

    static var allTests = [
        ("testFileIO", testFileIO),
        ("testGetRoot", testGetRoot),
        ("testDateFormatting", testDateFormatting)
    ]
}
