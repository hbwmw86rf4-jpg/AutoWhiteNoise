import Foundation

/// A named mix plus the behaviour that goes with it. Presets are what
/// automations, Siri and the local-network endpoint refer to by name.
public struct Preset: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var layers: [Layer]
    /// 0.0 to 1.0, applied on top of every layer's own volume.
    public var masterVolume: Double
    /// Seconds. 0 means start at full volume immediately.
    public var fadeInSeconds: Double
    /// Seconds. 0 means cut off immediately when stopped.
    public var fadeOutSeconds: Double
    /// Minutes until automatic stop. nil means play until told to stop.
    public var autoStopMinutes: Int?
    /// If set, automated starts (Shortcuts, network, schedule) are refused outside
    /// this window unless the trigger explicitly overrides it. Manual taps in the
    /// app always work.
    public var allowedWindow: TimeWindow?

    public init(
        id: UUID = UUID(),
        name: String,
        layers: [Layer],
        masterVolume: Double = 0.7,
        fadeInSeconds: Double = 10,
        fadeOutSeconds: Double = 5,
        autoStopMinutes: Int? = nil,
        allowedWindow: TimeWindow? = nil
    ) {
        self.id = id
        self.name = name
        self.layers = Array(layers.prefix(3))
        self.masterVolume = min(max(masterVolume, 0), 1)
        self.fadeInSeconds = max(fadeInSeconds, 0)
        self.fadeOutSeconds = max(fadeOutSeconds, 0)
        self.autoStopMinutes = autoStopMinutes.map { max($0, 1) }
        self.allowedWindow = allowedWindow
    }

    /// Case-insensitive, whitespace-tolerant match used by Siri phrases and URLs.
    public func matches(name query: String) -> Bool {
        Preset.normalize(name) == Preset.normalize(query)
    }

    public static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// The presets a fresh install starts with.
    public static let defaults: [Preset] = [
        Preset(name: "Fan", layers: [Layer(kind: .fan, volume: 0.9)], fadeInSeconds: 8),
        Preset(name: "Rain", layers: [Layer(kind: .rain, volume: 0.8), Layer(kind: .brown, volume: 0.3)], fadeInSeconds: 10),
        Preset(name: "Ocean", layers: [Layer(kind: .ocean, volume: 0.9)], fadeInSeconds: 12),
        Preset(name: "Brown", layers: [Layer(kind: .brown, volume: 0.9)], fadeInSeconds: 6),
        Preset(name: "Pink", layers: [Layer(kind: .pink, volume: 0.8)], fadeInSeconds: 6),
        Preset(name: "White", layers: [Layer(kind: .white, volume: 0.6)], fadeInSeconds: 6),
    ]
}
