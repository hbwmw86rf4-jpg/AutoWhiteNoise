import Foundation

/// Pure scheduling logic. Given the rules and the last time we checked, which
/// rules are due now? Kept free of timers so it can be unit-tested.
public enum ScheduleEngine {
    /// If the app was asleep (laptop lid closed) for longer than this, fires that
    /// were missed in the meantime are skipped rather than fired late. Nobody wants
    /// white noise starting at noon because a 5:30 rule was missed.
    public static let maxLateFire: TimeInterval = 120

    public struct Due: Equatable, Sendable {
        public var rule: ScheduleRule
        public var scheduledFor: Date
    }

    /// Rules whose fire time falls in (since, now]. If `now - since` is larger
    /// than `maxLateFire`, only fires within the last `maxLateFire` seconds count.
    public static func dueRules(_ rules: [ScheduleRule], since: Date, now: Date,
                                calendar: Calendar = .current) -> [Due] {
        let effectiveSince = max(since, now.addingTimeInterval(-maxLateFire))
        var due: [Due] = []
        for rule in rules where rule.enabled {
            var cursor = effectiveSince
            // A rule can fire at most once per day, so this loop runs 0 or 1 times
            // in practice; the bound guards against pathological clocks.
            var guardCount = 0
            while let next = rule.nextFireDate(after: cursor, calendar: calendar), next <= now, guardCount < 3 {
                due.append(Due(rule: rule, scheduledFor: next))
                cursor = next
                guardCount += 1
            }
        }
        return due.sorted { $0.scheduledFor < $1.scheduledFor }
    }

    /// The soonest upcoming fire across all rules, for display.
    public static func nextFire(_ rules: [ScheduleRule], after date: Date,
                                calendar: Calendar = .current) -> (ScheduleRule, Date)? {
        rules.compactMap { rule in rule.nextFireDate(after: date, calendar: calendar).map { (rule, $0) } }
            .min { $0.1 < $1.1 }
    }
}

/// Ticks every few seconds and fires due rules. Polling rather than one long
/// timer is deliberate: it survives system sleep, clock changes and time-zone
/// changes without special handling, and the cost is negligible.
public final class ScheduleRunner {
    public var rules: [ScheduleRule] = []
    public var onFire: ((ScheduleEngine.Due) -> Void)?
    public private(set) var lastTick: Date
    private var timer: DispatchSourceTimer?
    private let interval: TimeInterval
    private let queue: DispatchQueue

    public init(interval: TimeInterval = 15, queue: DispatchQueue = .main, now: Date = Date()) {
        self.interval = interval
        self.queue = queue
        self.lastTick = now
    }

    public var isRunning: Bool { timer != nil }

    public func start() {
        guard timer == nil else { return }
        lastTick = Date()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(2))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Exposed so tests and "app woke up" handlers can force a check.
    public func tick(now: Date = Date()) {
        let due = ScheduleEngine.dueRules(rules, since: lastTick, now: now)
        lastTick = now
        for d in due { onFire?(d) }
    }
}
