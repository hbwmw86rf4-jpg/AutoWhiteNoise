import Foundation

/// A wall-clock time without a date, e.g. 05:30.
public struct HourMinute: Codable, Equatable, Hashable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// Minutes since midnight. Makes comparisons trivial.
    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: HourMinute, rhs: HourMinute) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    public init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    /// "05:30"
    public var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Parses "5:30", "05:30" or "0530". Returns nil for anything else.
    public init?(parsing text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts: [String]
        if trimmed.contains(":") {
            parts = trimmed.split(separator: ":").map(String.init)
        } else if trimmed.count == 4 {
            parts = [String(trimmed.prefix(2)), String(trimmed.suffix(2))]
        } else {
            return nil
        }
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        self.init(hour: h, minute: m)
    }
}

/// A daily window such as 05:00 to 08:00. Windows may cross midnight
/// (22:00 to 06:00). A preset or trigger can refuse to start outside its window,
/// which is how "only react if she gets up between 5 and 8" is enforced in one
/// place instead of inside every automation.
public struct TimeWindow: Codable, Equatable, Hashable, Sendable {
    public var start: HourMinute
    public var end: HourMinute

    public init(start: HourMinute, end: HourMinute) {
        self.start = start
        self.end = end
    }

    public var crossesMidnight: Bool { end < start }

    /// Whether the given moment falls inside the window. `start` is inclusive,
    /// `end` is exclusive, so 05:00–08:00 contains 07:59 but not 08:00.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        contains(HourMinute(date: date, calendar: calendar))
    }

    public func contains(_ time: HourMinute) -> Bool {
        let t = time.minutesSinceMidnight
        let s = start.minutesSinceMidnight
        let e = end.minutesSinceMidnight
        if s == e { return true } // a zero-length window means "always"
        if crossesMidnight {
            return t >= s || t < e
        }
        return t >= s && t < e
    }

    public var formatted: String { "\(start.formatted)–\(end.formatted)" }
}
