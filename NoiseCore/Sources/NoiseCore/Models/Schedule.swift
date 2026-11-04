import Foundation

/// What a schedule does when it fires.
public enum ScheduleAction: Codable, Equatable, Sendable {
    case start(presetID: UUID)
    case stop
}

/// "At 05:30 on weekdays, start the Rain preset." The app's own scheduler runs
/// these on the Mac and in iPad appliance mode. On iPhone they are informational:
/// the Automations screen explains how to mirror one as a Shortcuts automation,
/// which is the only thing that can wake the app at a time.
public struct ScheduleRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var enabled: Bool
    public var time: HourMinute
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday. Empty means every day.
    public var weekdays: Set<Int>
    public var action: ScheduleAction

    public init(id: UUID = UUID(), name: String, enabled: Bool = true, time: HourMinute,
                weekdays: Set<Int> = [], action: ScheduleAction) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.time = time
        self.weekdays = Set(weekdays.filter { (1...7).contains($0) })
        self.action = action
    }

    public static let everyDay: Set<Int> = []
    public static let weekdaysOnly: Set<Int> = [2, 3, 4, 5, 6]
    public static let weekendOnly: Set<Int> = [1, 7]

    /// The next moment strictly after `date` at which this rule should fire,
    /// or nil if the rule is disabled. Walks forward day by day, which is simple
    /// and fast enough for a handful of rules.
    public func nextFireDate(after date: Date, calendar: Calendar = .current) -> Date? {
        guard enabled else { return nil }
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date),
                  let candidate = calendar.date(bySettingHour: time.hour, minute: time.minute,
                                                second: 0, of: day) else { continue }
            guard candidate > date else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            if weekdays.isEmpty || weekdays.contains(weekday) {
                return candidate
            }
        }
        return nil
    }

    public var weekdaysDescription: String {
        if weekdays.isEmpty { return "Every day" }
        if weekdays == ScheduleRule.weekdaysOnly { return "Weekdays" }
        if weekdays == ScheduleRule.weekendOnly { return "Weekends" }
        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdays.sorted().map { names[$0] }.joined(separator: " ")
    }
}
