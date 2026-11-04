import XCTest
@testable import NoiseCore

final class StorageTests: XCTestCase {
    func testRoundTrip() throws {
        let storage = Storage.temporary()
        let presets = [Preset(name: "A", layers: [Layer(kind: .ocean, volume: 0.3)],
                              allowedWindow: TimeWindow(start: HourMinute(hour: 22, minute: 0), end: HourMinute(hour: 6, minute: 0)))]
        try storage.presets.save(presets)
        XCTAssertEqual(storage.presets.load(), presets)

        var log = TriggerLog(limit: 2)
        log.append(TriggerEvent(source: .manual, outcome: .started, presetName: "A"))
        log.append(TriggerEvent(source: .network, outcome: .stopped))
        log.append(TriggerEvent(source: .schedule, outcome: .started))
        XCTAssertEqual(log.events.count, 2, "log is bounded")
        XCTAssertEqual(log.events.first?.source, .schedule, "newest first")
        try storage.log.save(log)
        XCTAssertEqual(storage.log.load()?.events.map(\.id), log.events.map(\.id))
    }

    func testMissingFileLoadsNil() {
        XCTAssertNil(Storage.temporary().settings.load())
    }
}
