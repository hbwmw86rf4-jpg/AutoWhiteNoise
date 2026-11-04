import Foundation

/// What the player needs from "the thing that makes sound". The real one wraps
/// AVAudioEngine; tests use a fake. Keeping this boundary means the player's
/// rules (fades, windows, logging) are testable on Linux.
public protocol AudioBackend: AnyObject {
    var isRunning: Bool { get }
    /// Starts producing sound for these layers at this master volume (0–1).
    func start(layers: [Layer], masterVolume: Float) throws
    func stop()
    func setMasterVolume(_ volume: Float)
    func setLayerVolume(index: Int, volume: Float)
    /// Called by the backend when the system interrupted and then released audio
    /// (phone call ended, Siri finished). The player decides whether to resume.
    var onInterruptionEnded: ((_ shouldResume: Bool) -> Void)? { get set }
}

/// Records calls instead of playing. For tests.
public final class RecordingAudioBackend: AudioBackend {
    public private(set) var isRunning = false
    public private(set) var startedLayers: [[Layer]] = []
    public private(set) var masterVolumes: [Float] = []
    public private(set) var stopCount = 0
    public var failNextStart = false
    public var onInterruptionEnded: ((Bool) -> Void)?

    public init() {}

    public struct Failure: Error {}

    public func start(layers: [Layer], masterVolume: Float) throws {
        if failNextStart { failNextStart = false; throw Failure() }
        startedLayers.append(layers)
        masterVolumes.append(masterVolume)
        isRunning = true
    }

    public func stop() { stopCount += 1; isRunning = false }
    public func setMasterVolume(_ volume: Float) { masterVolumes.append(volume) }
    public func setLayerVolume(index: Int, volume: Float) {}
}
