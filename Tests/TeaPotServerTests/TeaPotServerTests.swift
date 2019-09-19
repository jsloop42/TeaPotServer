import XCTest
import class Foundation.Bundle
import Logging
import TeaPotServer

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

final class TeaPotServerTests: XCTestCase {
    private var isLoggerInitialized = false
    private lazy var log: LoggingService = {
        if !self.isLoggerInitialized {
            _ = LoggingService.init(level: .debug)
        }
        return Log!
    }()
    private let http = HTTPClient()
    private let state: State = State.shared.startServer()
    private let baseURL = "https://[::1]:4430"

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
        if let url = URL(string: "\(self.baseURL)/") {
            self.http.get(url) { data in
                if let aData = data {
                    let str = String(data: aData, encoding: .utf8)
                    Log?.debug("GET / - \(String(describing: str))")
                    let json = try? JSONDecoder().decode(TSResponseOK.self, from: aData)
                    XCTAssertNotNil(json)
                    XCTAssertTrue(json!.status)
                    XCTAssertEqual(json!.data, "ok")
                    expectation.fulfill()
                }
            }
            wait(for: [expectation], timeout: 10)
        } else {
            XCTAssert(false, "Constructing URL failed")
        }
    }

    func testPostReverse() {
        XCTAssertTrue(State.shared.isServerRunning)
        let expectation = XCTestExpectation(description: "POST /reverse")
        if let url = URL(string: "\(self.baseURL)/reverse") {
            let req = TSRequestGeneric(msg: "42")
            let data = try? JSONEncoder().encode(req)
            XCTAssertNotNil(data)
            self.http.post(url, data: data, headers: ["content-type": MimeType.json.rawValue], completion: { res in
                if let aData = res {
                    let str = String(data: aData, encoding: .utf8)
                    Log?.debug("POST /reverse: \(String(describing: str))")
                    let json = try? JSONDecoder().decode(TSResponseOK.self, from: aData)
                    XCTAssertNotNil(json)
                    XCTAssertTrue(json!.status)
                    XCTAssertEqual(json!.data, "24")
                    expectation.fulfill()
                }
            })
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
