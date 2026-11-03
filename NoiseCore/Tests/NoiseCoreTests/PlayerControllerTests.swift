import XCTest
@testable import NoiseCore

/// XCTest on Linux crashes when a test class is `@MainActor`, so each test
/// hops onto the main actor explicitly. The tests run on the main thread, so
/// `assumeIsolated` is a no-op check rather than a context switch.
final class PlayerControllerTests: XCTestCase {
    var backend: RecordingAudioBackend!
    var controller: PlayerController!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            backend = RecordingAudioBackend()
            controller = PlayerController(backend: backend, storage: .temporary())
        }
    }

    func instantPreset(_ name: String, window: TimeWindow? = nil) -> Preset {
        Preset(name: name, layers: [Layer(kind: .white)], masterVolume: 0.5,
               fadeInSeconds: 0, fadeOutSeconds: 0, allowedWindow: window)
    }

    func testStartsWithDefaultPresets() {
        MainActor.assumeIsolated {
            XCTAssertEqual(controller.presets.map(\.name), Preset.defaults.map(\.name))
            XCTAssertFalse(controller.isPlaying)
        }
    }

    func testStartAndStop() {
        MainActor.assumeIsolated {
            let p = instantPreset("Test")
            let result = controller.start(p, source: .manual)
            XCTAssertEqual(result, .started(p))
            XCTAssertTrue(controller.isPlaying)
            XCTAssertTrue(backend.isRunning)
            XCTAssertEqual(backend.startedLayers.first, p.layers)
            XCTAssertEqual(controller.liveMasterVolume, 0.5)
            controller.stop(source: .manual)
            XCTAssertFalse(controller.isPlaying)
            XCTAssertEqual(backend.stopCount, 1)
            XCTAssertEqual(controller.log.events.map(\.outcome), [.stopped, .started])
        }
    }

    func testFadeInStartsSilent() {
        MainActor.assumeIsolated {
            let p = Preset(name: "F", layers: [Layer(kind: .pink)], masterVolume: 0.8, fadeInSeconds: 5)
            controller.start(p, source: .manual)
            XCTAssertEqual(backend.masterVolumes.first, 0, "fade-in must begin at silence")
        }
    }

    func testAutomatedStartRefusedOutsideWindow() {
        MainActor.assumeIsolated {
            let window = TimeWindow(start: HourMinute(hour: 5, minute: 0), end: HourMinute(hour: 8, minute: 0))
            let p = instantPreset("Windowed", window: window)
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
            let result = controller.start(p, source: .shortcut, now: noon)
            XCTAssertEqual(result, .refusedOutsideWindow(p))
            XCTAssertFalse(controller.isPlaying)
            XCTAssertEqual(controller.log.events.first?.outcome, .refusedOutsideWindow)
        }
    }

    func testManualStartIgnoresWindow() {
        MainActor.assumeIsolated {
            let window = TimeWindow(start: HourMinute(hour: 5, minute: 0), end: HourMinute(hour: 8, minute: 0))
            let p = instantPreset("Windowed", window: window)
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
            XCTAssertEqual(controller.start(p, source: .manual, now: noon), .started(p))
        }
    }

    func testIgnoreWindowFlagOverrides() {
        MainActor.assumeIsolated {
            let window = TimeWindow(start: HourMinute(hour: 5, minute: 0), end: HourMinute(hour: 8, minute: 0))
            let p = instantPreset("Windowed", window: window)
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
            XCTAssertEqual(controller.start(p, source: .network, ignoreWindow: true, now: noon), .started(p))
        }
    }

    func testStartByNameIsCaseAndSpaceInsensitive() {
        MainActor.assumeIsolated {
            let p = instantPreset("Deep Rain")
            controller.upsert(p)
            let r = controller.start(named: "deeprain", source: .shortcut)
            XCTAssertEqual(r, .started(p))
        }
    }

    func testUnknownPresetName() {
        MainActor.assumeIsolated {
            let r = controller.start(named: "nothing here", source: .shortcut)
            XCTAssertEqual(r, .unknownPreset("nothing here"))
            XCTAssertEqual(controller.log.events.first?.outcome, .refusedUnknownPreset)
        }
    }

    func testStartSamePresetTwiceDoesNotRestart() {
        MainActor.assumeIsolated {
            let p = instantPreset("Once")
            controller.start(p, source: .manual)
            let r = controller.start(p, source: .manual)
            XCTAssertEqual(r, .alreadyPlaying(p))
            XCTAssertEqual(backend.startedLayers.count, 1)
        }
    }

    func testBackendFailureIsReported() {
        MainActor.assumeIsolated {
            backend.failNextStart = true
            let r = controller.start(instantPreset("X"), source: .manual)
            if case .failed = r {} else { XCTFail("expected failure, got \(r)") }
            XCTAssertFalse(controller.isPlaying)
        }
    }

    func testAutoStopIsScheduled() {
        MainActor.assumeIsolated {
            let p = instantPreset("Timed")
            let now = Date()
            controller.start(p, source: .manual, minutes: 45, now: now)
            XCTAssertEqual(controller.stopAt, now.addingTimeInterval(45 * 60))
        }
    }

    func testNetworkHandlerRejectsBadToken() {
        MainActor.assumeIsolated {
            let req = ControlRequest(rawHTTP: "GET /start?token=wrong HTTP/1.1\r\n\r\n")!
            let resp = controller.handle(req)
            XCTAssertEqual(resp.status, 401)
            XCTAssertFalse(controller.isPlaying)
            XCTAssertEqual(controller.log.events.first?.outcome, .refusedBadToken)
        }
    }

    func testNetworkHandlerStartsStopsAndReportsStatus() {
        MainActor.assumeIsolated {
            controller.upsert(instantPreset("NetRain"))
            let token = controller.settings.controlToken
            let start = controller.handle(ControlRequest(rawHTTP: "GET /start?preset=NetRain&token=\(token) HTTP/1.1\r\n\r\n")!)
            XCTAssertEqual(start.status, 200)
            XCTAssertTrue(controller.isPlaying)
            XCTAssertEqual(controller.lastStartSource, .network)
            let status = controller.handle(ControlRequest(rawHTTP: "GET /status?token=\(token) HTTP/1.1\r\n\r\n")!)
            XCTAssertTrue(status.body.contains(#""playing":true"#))
            XCTAssertTrue(status.body.contains(#""preset":"NetRain""#))
            let stop = controller.handle(ControlRequest(rawHTTP: "GET /stop?token=\(token) HTTP/1.1\r\n\r\n")!)
            XCTAssertEqual(stop.status, 200)
            XCTAssertFalse(controller.isPlaying)
            let unknown = controller.handle(ControlRequest(rawHTTP: "GET /what?token=\(token) HTTP/1.1\r\n\r\n")!)
            XCTAssertEqual(unknown.status, 404)
        }
    }

    func testPresetsPersistAcrossInstances() {
        MainActor.assumeIsolated {
            let storage = Storage.temporary()
            let c1 = PlayerController(backend: RecordingAudioBackend(), storage: storage)
            let custom = instantPreset("Mine")
            c1.upsert(custom)
            c1.schedules = [ScheduleRule(name: "Morning", time: HourMinute(hour: 5, minute: 30), action: .start(presetID: custom.id))]
            let c2 = PlayerController(backend: RecordingAudioBackend(), storage: storage)
            XCTAssertTrue(c2.presets.contains(custom))
            XCTAssertEqual(c2.schedules.count, 1)
            XCTAssertEqual(c2.settings.controlToken, c1.settings.controlToken)
        }
    }

    func testDeletingPresetRemovesItsSchedules() {
        MainActor.assumeIsolated {
            let p = instantPreset("Gone")
            controller.upsert(p)
            controller.schedules = [ScheduleRule(name: "s", time: HourMinute(hour: 1, minute: 0), action: .start(presetID: p.id))]
            controller.delete(presetID: p.id)
            XCTAssertTrue(controller.schedules.isEmpty)
            XCTAssertNil(controller.preset(id: p.id))
        }
    }

    func testScheduleFireStartsPreset() {
        MainActor.assumeIsolated {
            let p = instantPreset("Sched")
            controller.upsert(p)
            let rule = ScheduleRule(name: "r", time: HourMinute(hour: 5, minute: 30), action: .start(presetID: p.id))
            controller.schedules = [rule]
            // Drive the runner by hand with a tick that straddles 05:30 local time.
            let cal = Calendar.current
            let fire = cal.date(bySettingHour: 5, minute: 30, second: 0, of: cal.startOfDay(for: Date()))!
            let runner = controller.runner
            runner.tick(now: fire.addingTimeInterval(-10))
            runner.tick(now: fire.addingTimeInterval(10))
            // onFire hops to the main actor via Task; give it a moment.
            let exp = expectation(description: "fired")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                exp.fulfill()
            }
            wait(for: [exp], timeout: 2)
            XCTAssertTrue(controller.isPlaying)
            XCTAssertEqual(controller.lastStartSource, .schedule)
        }
    }
}
