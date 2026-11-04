import XCTest
@testable import NoiseCore

final class ScheduleTests: XCTestCase {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testNextFireLaterToday() {
        let rule = ScheduleRule(name: "x", time: HourMinute(hour: 5, minute: 30), action: .stop)
        let now = date(2026, 11, 3, 4, 0) // Tuesday 04:00
        XCTAssertEqual(rule.nextFireDate(after: now, calendar: cal), date(2026, 11, 3, 5, 30))
    }

    func testNextFireRollsToTomorrowWhenTimePassed() {
        let rule = ScheduleRule(name: "x", time: HourMinute(hour: 5, minute: 30), action: .stop)
        let now = date(2026, 11, 3, 5, 30) // exactly at fire time: must be strictly after
        XCTAssertEqual(rule.nextFireDate(after: now, calendar: cal), date(2026, 11, 4, 5, 30))
    }

    func testWeekdayFilter() {
        // 2026-11-06 is a Friday; next weekday fire after Friday 06:00 is Monday 11-09.
        let rule = ScheduleRule(name: "x", time: HourMinute(hour: 5, minute: 30),
                                weekdays: ScheduleRule.weekdaysOnly, action: .stop)
        let now = date(2026, 11, 6, 6, 0)
        XCTAssertEqual(rule.nextFireDate(after: now, calendar: cal), date(2026, 11, 9, 5, 30))
    }

    func testDisabledRuleNeverFires() {
        let rule = ScheduleRule(name: "x", enabled: false, time: HourMinute(hour: 5, minute: 30), action: .stop)
        XCTAssertNil(rule.nextFireDate(after: date(2026, 11, 3, 0, 0), calendar: cal))
    }

    func testDueRulesWithinTick() {
        let rule = ScheduleRule(name: "x", time: HourMinute(hour: 5, minute: 30), action: .stop)
        let since = date(2026, 11, 3, 5, 29)
        let now = date(2026, 11, 3, 5, 30)
        let due = ScheduleEngine.dueRules([rule], since: since, now: now, calendar: cal)
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due.first?.scheduledFor, date(2026, 11, 3, 5, 30))
    }

    func testMissedFireAfterLongSleepIsSkipped() {
        // Laptop lid closed from 05:00 to 12:00. The 05:30 rule must NOT fire at noon.
        let rule = ScheduleRule(name: "x", time: HourMinute(hour: 5, minute: 30), action: .stop)
        let since = date(2026, 11, 3, 5, 0)
        let now = date(2026, 11, 3, 12, 0)
        XCTAssertTrue(ScheduleEngine.dueRules([rule], since: since, now: now, calendar: cal).isEmpty)
    }

    func testSlightlyLateFireStillHappens() {
        // A 60-second hiccup is fine.
        let rule = ScheduleRule(name: "x", time: HourMinute(hour: 5, minute: 30), action: .stop)
        let since = date(2026, 11, 3, 5, 29)
        let now = date(2026, 11, 3, 5, 31)
        XCTAssertEqual(ScheduleEngine.dueRules([rule], since: since, now: now, calendar: cal).count, 1)
    }

    func testRunnerTickFiresCallback() {
        let runner = ScheduleRunner(interval: 1000, now: date(2026, 11, 3, 5, 29))
        let rule = ScheduleRule(name: "x", time: HourMinute(hour: 5, minute: 30), action: .stop)
        runner.rules = [rule]
        var fired: [ScheduleEngine.Due] = []
        runner.onFire = { fired.append($0) }
        // The runner uses Calendar.current; pick a 'now' that is one minute after
        // the rule in the current calendar's time zone.
        let localCal = Calendar.current
        let today = localCal.startOfDay(for: Date())
        let fireTime = localCal.date(bySettingHour: 5, minute: 30, second: 0, of: today)!
        _ = runner // silence unused warnings in some toolchains
        let r2 = ScheduleRunner(interval: 1000, now: fireTime.addingTimeInterval(-30))
        r2.rules = [rule]
        r2.onFire = { fired.append($0) }
        r2.tick(now: fireTime.addingTimeInterval(30))
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(r2.lastTick, fireTime.addingTimeInterval(30))
    }

    func testWeekdaysDescription() {
        XCTAssertEqual(ScheduleRule(name: "a", time: HourMinute(hour: 1, minute: 0), action: .stop).weekdaysDescription, "Every day")
        XCTAssertEqual(ScheduleRule(name: "a", time: HourMinute(hour: 1, minute: 0), weekdays: ScheduleRule.weekdaysOnly, action: .stop).weekdaysDescription, "Weekdays")
        XCTAssertEqual(ScheduleRule(name: "a", time: HourMinute(hour: 1, minute: 0), weekdays: [1, 4], action: .stop).weekdaysDescription, "Sun Wed")
    }
}
