import Foundation

/// The kinds of sound the engine can synthesise. All of these are generated
/// mathematically at run time, so the app ships with no audio files and the
/// sound never has a loop seam. Recorded sounds can be added later as a new case
/// that points at a bundled file.
public enum SoundKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case white
    case pink
    case brown
    case fan
    case ocean
    case rain

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .white: return "White noise"
        case .pink: return "Pink noise"
        case .brown: return "Brown noise"
        case .fan: return "Fan"
        case .ocean: return "Ocean"
        case .rain: return "Rain"
        }
    }

    public var blurb: String {
        switch self {
        case .white: return "Even hiss across all frequencies. The classic."
        case .pink: return "Softer than white, more bass. Like steady rain on a roof."
        case .brown: return "Deep rumble, very little hiss. Like a distant waterfall."
        case .fan: return "Low, smooth whoosh modelled on a box fan or air purifier."
        case .ocean: return "Brown noise that swells and recedes like waves."
        case .rain: return "Bright patter with a soft bed underneath."
        }
    }
}

/// One sound at one volume. A preset mixes up to three of these.
public struct Layer: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: SoundKind
    /// 0.0 to 1.0
    public var volume: Double

    public init(id: UUID = UUID(), kind: SoundKind, volume: Double = 0.8) {
        self.id = id
        self.kind = kind
        self.volume = min(max(volume, 0), 1)
    }
}
