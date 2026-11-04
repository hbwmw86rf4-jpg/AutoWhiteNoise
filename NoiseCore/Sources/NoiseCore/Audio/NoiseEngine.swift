#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// The real audio backend. One AVAudioSourceNode per layer feeds the main
/// mixer; each node pulls samples from a pair of NoiseGenerators (left/right)
/// on the real-time audio thread. Master volume is the mixer's output volume.
///
/// Thread notes: `start`/`stop` run on the main thread. The render closures run
/// on Core Audio's thread and only read `gain`, a Float written from the main
/// thread; a torn read of a Float is impossible on arm64/x86-64, so no lock.
public final class NoiseEngine: AudioBackend {
    public private(set) var isRunning = false
    public var onInterruptionEnded: ((Bool) -> Void)?
    public var mixWithOthers = false

    private let engine = AVAudioEngine()
    private var sourceNodes: [AVAudioSourceNode] = []
    private var layerBoxes: [LayerBox] = []
    private var observers: [NSObjectProtocol] = []

    /// Holds the per-channel generators for one layer. A class so the render
    /// closure can mutate the generators in place without copying.
    private final class LayerBox: @unchecked Sendable {
        var generators: [NoiseGenerator]
        var gain: Float
        init(generators: [NoiseGenerator], gain: Float) {
            self.generators = generators
            self.gain = gain
        }
    }

    public init() {
        installObservers()
    }

    deinit {
        for o in observers { NotificationCenter.default.removeObserver(o) }
    }

    public func start(layers: [Layer], masterVolume: Float) throws {
        stop()
        try activateSession()

        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44_100
        let channels: AVAudioChannelCount = 2
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels) else {
            throw EngineError.badFormat
        }

        for (index, layer) in layers.enumerated() {
            let seedBase = UInt64(index &+ 1) &* 0x9E37_79B9
            let box = LayerBox(
                generators: (0..<Int(channels)).map { ch in
                    NoiseGenerator(kind: layer.kind, sampleRate: Float(sampleRate), seed: seedBase &+ UInt64(ch) &* 7919)
                },
                gain: Float(layer.volume)
            )
            let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let gain = box.gain
                for (ch, buffer) in buffers.enumerated() where ch < box.generators.count {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    box.generators[ch].render(into: samples, count: Int(frameCount), gain: gain)
                }
                return noErr
            }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            sourceNodes.append(node)
            layerBoxes.append(box)
        }

        engine.mainMixerNode.outputVolume = masterVolume
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    public func stop() {
        if engine.isRunning { engine.stop() }
        for node in sourceNodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        sourceNodes.removeAll()
        layerBoxes.removeAll()
        isRunning = false
        deactivateSession()
    }

    public func setMasterVolume(_ volume: Float) {
        engine.mainMixerNode.outputVolume = min(max(volume, 0), 1)
    }

    public func setLayerVolume(index: Int, volume: Float) {
        guard layerBoxes.indices.contains(index) else { return }
        layerBoxes[index].gain = min(max(volume, 0), 1)
    }

    public enum EngineError: Error, LocalizedError {
        case badFormat
        public var errorDescription: String? { "Could not create an audio format." }
    }

    // MARK: Audio session (iOS / iPadOS only; macOS has no AVAudioSession)

    private func activateSession() throws {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        // .playback is what lets audio continue with the screen locked, together
        // with the "audio" background mode in Info.plist.
        try session.setCategory(.playback, mode: .default, options: mixWithOthers ? [.mixWithOthers] : [])
        try session.setActive(true)
        #endif
    }

    private func deactivateSession() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        // notifyOthersOnDeactivation lets music that we interrupted resume.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func installObservers() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            switch type {
            case .began:
                // The system paused us (phone call, Siri, alarm). Nothing to do; the
                // engine stops on its own.
                break
            case .ended:
                let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
                self.onInterruptionEnded?(shouldResume)
            @unknown default:
                break
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            // Headphones unplugged: iOS pauses output. Treat it like an interruption
            // that should resume, so the sound continues from the speaker.
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                  reason == .oldDeviceUnavailable, self.isRunning, !self.engine.isRunning else { return }
            self.onInterruptionEnded?(true)
        })
        #endif
    }
}
#endif
