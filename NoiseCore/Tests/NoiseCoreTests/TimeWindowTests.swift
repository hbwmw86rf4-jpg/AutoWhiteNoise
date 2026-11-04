import XCTest
@testable import NoiseCore

final class TimeWindowTests: XCTestCase {
    func testParsing() {
        XCTAssertEqual(HourMinute(parsing: "5:30"), HourMinute(hour: 5, minute: 30))
        XCTAssertEqual(HourMinute(parsing: "05:30"), HourMinute(hour: 5, minute: 30))
        XCTAssertEqual(HourMinute(parsing: "0530"), HourMinute(hour: 5, minute: 30))
        XCTAssertNil(HourMinute(parsing: "25:00"))
        XCTAssertNil(HourMinute(parsing: "hello"))
        XCTAssertEqual(HourMinute(hour: 5, minute: 30).formatted, "05:30")
    }

    func testDaytimeWindow() {
        let w = TimeWindow(start: HourMinute(hour: 5, minute: 0), end: HourMinute(hour: 8, minute: 0))
        XCTAssertFalse(w.crossesMidnight)
        XCTAssertTrue(w.contains(HourMinute(hour: 5, minute: 0)))
        XCTAssertTrue(w.contains(HourMinute(hour: 7, minute: 59)))
        XCTAssertFalse(w.contains(HourMinute(hour: 8, minute: 0)), "end is exclusive")
        XCTAssertFalse(w.contains(HourMinute(hour: 4, minute: 59)))
        XCTAssertFalse(w.contains(HourMinute(hour: 23, minute: 0)))
    }

    func testOvernightWindow() {
        let w = TimeWindow(start: HourMinute(hour: 22, minute: 0), end: HourMinute(hour: 6, minute: 0))
        XCTAssertTrue(w.crossesMidnight)
        XCTAssertTrue(w.contains(HourMinute(hour: 23, minute: 30)))
        XCTAssertTrue(w.contains(HourMinute(hour: 0, minute: 0)))
        XCTAssertTrue(w.contains(HourMinute(hour: 5, minute: 59)))
        XCTAssertFalse(w.contains(HourMinute(hour: 6, minute: 0)))
        XCTAssertFalse(w.contains(HourMinute(hour: 12, minute: 0)))
    }

    func testZeroLengthWindowMeansAlways() {
        let w = TimeWindow(start: HourMinute(hour: 3, minute: 0), end: HourMinute(hour: 3, minute: 0))
        XCTAssertTrue(w.contains(HourMinute(hour: 15, minute: 0)))
    }

    func testContainsDateUsesCalendar() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 6, minute: 15))!
        let w = TimeWindow(start: HourMinute(hour: 5, minute: 0), end: HourMinute(hour: 8, minute: 0))
        XCTAssertTrue(w.contains(date, calendar: cal))
    }
}
