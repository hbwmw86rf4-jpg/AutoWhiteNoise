import Foundation

/// Where a start or stop request came from. Shown in the log so "why did it
/// go off at 3 AM?" has an answer.
public enum TriggerSource: String, Codable, Sendable, CaseIterable {
    case manual        // a tap in the app
    case shortcut      // Shortcuts automation, Siri, Action Button, widget
    case network       // the local-network endpoint
    case schedule      // the app's own scheduler (Mac / appliance mode)
    case remote        // lock screen / Control Center media buttons
    case autoStop      // the preset's own stop timer

    public var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .shortcut: return "Shortcut"
        case .network: return "Network"
        case .schedule: return "Schedule"
        case .remote: return "Media controls"
        case .autoStop: return "Auto-stop"
        }
    }
}

public enum TriggerOutcome: String, Codable, Sendable {
    case started
    case stopped
    case refusedOutsideWindow
    case refusedUnknownPreset
    case refusedBadToken
    case failed
}

public struct TriggerEvent: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var source: TriggerSource
    public var outcome: TriggerOutcome
    public var presetName: String?
    public var detail: String?

    public init(id: UUID = UUID(), date: Date = Date(), source: TriggerSource,
                outcome: TriggerOutcome, presetName: String? = nil, detail: String? = nil) {
        self.id = id
        self.date = date
        self.source = source
        self.outcome = outcome
        self.presetName = presetName
        self.detail = detail
    }
}

/// A bounded, newest-first list of events.
public struct TriggerLog: Codable, Equatable, Sendable {
    public private(set) var events: [TriggerEvent]
    public var limit: Int

    public init(events: [TriggerEvent] = [], limit: Int = 500) {
        self.events = events
        self.limit = limit
    }

    public mutating func append(_ event: TriggerEvent) {
        events.insert(event, at: 0)
        if events.count > limit { events.removeLast(events.count - limit) }
    }

    public mutating func clear() { events.removeAll() }
}
