import XCTest
@testable import NoiseCore

final class ControlProtocolTests: XCTestCase {
    func testParsesStartWithAllParameters() {
        let raw = "GET /start?preset=Deep%20Rain&fade=12.5&minutes=90&force=1&token=abc HTTP/1.1\r\nHost: x\r\n\r\n"
        let req = ControlRequest(rawHTTP: raw)!
        XCTAssertEqual(req.method, "GET")
        XCTAssertEqual(req.path, "/start")
        XCTAssertEqual(req.token, "abc")
        XCTAssertEqual(req.command, .start(preset: "Deep Rain", fadeSeconds: 12.5, minutes: 90, ignoreWindow: true))
    }

    func testPlusDecodesToSpace() {
        let req = ControlRequest(rawHTTP: "GET /start?preset=Deep+Rain HTTP/1.1\r\n\r\n")!
        XCTAssertEqual(req.query["preset"], "Deep Rain")
    }

    func testAliases() {
        XCTAssertEqual(ControlRequest(rawHTTP: "GET /on HTTP/1.1\r\n\r\n")!.command,
                       .start(preset: nil, fadeSeconds: nil, minutes: nil, ignoreWindow: false))
        XCTAssertEqual(ControlRequest(rawHTTP: "GET /off?fade=3 HTTP/1.1\r\n\r\n")!.command, .stop(fadeSeconds: 3))
        XCTAssertEqual(ControlRequest(rawHTTP: "GET / HTTP/1.1\r\n\r\n")!.command, .status)
        XCTAssertEqual(ControlRequest(rawHTTP: "GET /presets HTTP/1.1\r\n\r\n")!.command, .presets)
        XCTAssertNil(ControlRequest(rawHTTP: "GET /nope HTTP/1.1\r\n\r\n")!.command)
    }

    func testMalformedRequestLine() {
        XCTAssertNil(ControlRequest(rawHTTP: ""))
        XCTAssertNil(ControlRequest(rawHTTP: "GARBAGE"))
    }

    func testResponseFormat() {
        let r = ControlResponse.ok(["ok": true, "preset": "Rain"])
        let raw = r.rawHTTP
        XCTAssertTrue(raw.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(raw.contains("Content-Type: application/json"))
        XCTAssertTrue(raw.contains("Content-Length: \(r.body.utf8.count)\r\n"))
        XCTAssertTrue(raw.hasSuffix("\r\n\r\n" + r.body))
        XCTAssertEqual(r.body, #"{"ok":true,"preset":"Rain"}"#)
    }

    func testTokenShape() {
        let t = ControlToken.generate()
        XCTAssertEqual(t.count, 12)
        XCTAssertNotEqual(t, ControlToken.generate())
    }
}
