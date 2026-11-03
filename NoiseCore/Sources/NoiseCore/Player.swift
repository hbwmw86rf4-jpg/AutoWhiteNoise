import Foundation
import Observation

/// The result of asking the player to start. Automations get this back so the
/// log and the Shortcuts dialog can say what happened.
public enum StartResult: Equatable, Sendable {
    case started(Preset)
    case alreadyPlaying(Preset)
    case refusedOutsideWindow(Preset)
    case unknownPreset(String)
    case failed(String)

    public var message: String {
        switch self {
        case .started(let p): return "Started \(p.name)."
        case .alreadyPlaying(let p): return "\(p.name) is already playing."
        case .refusedOutsideWindow(let p): return "\(p.name) is outside its allowed hours, not started."
        case .unknownPreset(let name): return "No preset called \(name)."
        case .failed(let why): return "Could not start: \(why)"
        }
    }
}

/// The one object every door leads to: the UI, App Intents, the network
/// endpoint and the scheduler all call `start` and `stop` here. It owns the
/// presets, schedules, settings and log, and persists them.
///
/// Marked @MainActor because SwiftUI observes it and because that keeps all the
/// bookkeeping single-threaded; the audio thread lives inside the backend.
/// `@Observable` is Swift's Observation framework: SwiftUI views that read a
/// property are redrawn when it changes, with no `@Published` boilerplate.
@MainActor
@Observable
public final class PlayerController {
    public private(set) var isPlaying = false
    public private(set) var currentPreset: Preset?
    public private(set) var stopAt: Date?
    public private(set) var lastStartSource: TriggerSource?
    public private(set) var liveMasterVolume: Double = 0
    public var presets: [Preset] { didSet { try? storage.presets.save(presets) } }
    public var schedules: [ScheduleRule] { didSet { try? storage.schedules.save(schedules); runner.rules = schedules } }
    public var settings: AppSettings { didSet { try? storage.settings.save(settings) } }
    public private(set) var log: TriggerLog { didSet { try? storage.log.save(log) } }
    public private(set) var lastError: String?

    @ObservationIgnored public let backend: AudioBackend
    @ObservationIgnored public let storage: Storage
    @ObservationIgnored public let runner: ScheduleRunner

    @ObservationIgnored private var fadeTimer: Timer?
    @ObservationIgnored private var stopTimer: Timer?
    @ObservationIgnored private var targetMasterVolume: Double = 0

    public init(backend: AudioBackend, storage: Storage, runner: ScheduleRunner = ScheduleRunner()) {
        self.backend = backend
        self.storage = storage
        self.runner = runner
        self.presets = storage.presets.load() ?? Preset.defaults
        self.schedules = storage.schedules.load() ?? []
        self.settings = storage.settings.load() ?? AppSettings()
        self.log = storage.log.load() ?? TriggerLog()
        // Property observers do not run during init, so persist first-run defaults
        // explicitly. Otherwise the control token would be regenerated on every
        // launch until the user changed some setting.
        if storage.settings.load() == nil { try? storage.settings.save(settings) }
        if storage.presets.load() == nil { try? storage.presets.save(presets) }
        runner.rules = schedules
        runner.onFire = { [weak self] due in
            Task { @MainActor in self?.fire(due) }
        }
        backend.onInterruptionEnded = { [weak self] shouldResume in
            Task { @MainActor in
                guard let self, shouldResume, let preset = self.currentPreset, self.isPlaying else { return }
                try? self.backend.start(layers: preset.layers, masterVolume: Float(self.liveMasterVolume))
            }
        }
    }

    // MARK: Lookup

    public func preset(named name: String) -> Preset? {
        presets.first { $0.matches(name: name) }
    }

    public func preset(id: UUID) -> Preset? {
        presets.first { $0.id == id }
    }

    // MARK: Start / stop

    /// Starts a preset. `source` is for the log. Automated sources respect the
    /// preset's allowed window unless `ignoreWindow` is set; manual taps never
    /// check it. `fadeIn`/`minutes` override the preset's own values.
    @discardableResult
    public func start(_ preset: Preset, source: TriggerSource, fadeIn: Double? = nil,
                      minutes: Int? = nil, ignoreWindow: Bool = false, now: Date = Date()) -> StartResult {
        if source != .manual, !ignoreWindow, let window = preset.allowedWindow, !window.contains(now) {
            record(.init(source: source, outcome: .refusedOutsideWindow, presetName: preset.name,
                         detail: "Allowed \(window.formatted)"))
            return .refusedOutsideWindow(preset)
        }
        if isPlaying, currentPreset?.id == preset.id {
            // Same preset again: just refresh the auto-stop, don't restart the sound.
            scheduleAutoStop(minutes: minutes ?? preset.autoStopMinutes, from: now)
            return .alreadyPlaying(preset)
        }

        let fade = fadeIn ?? preset.fadeInSeconds
        let startVolume: Double = fade > 0 ? 0 : preset.masterVolume
        do {
            try backend.start(layers: preset.layers, masterVolume: Float(startVolume))
        } catch {
            lastError = "\(error)"
            record(.init(source: source, outcome: .failed, presetName: preset.name, detail: "\(error)"))
            return .failed("\(error)")
        }
        isPlaying = true
        currentPreset = preset
        lastStartSource = source
        liveMasterVolume = startVolume
        fadeMaster(to: preset.masterVolume, over: fade)
        scheduleAutoStop(minutes: minutes ?? preset.autoStopMinutes, from: now)
        record(.init(source: source, outcome: .started, presetName: preset.name,
                     detail: minutes.map { "Stop after \($0) min" }))
        return .started(preset)
    }

    /// Convenience for callers that only have a name (Siri, URL).
    @discardableResult
    public func start(named name: String?, source: TriggerSource, fadeIn: Double? = nil,
                      minutes: Int? = nil, ignoreWindow: Bool = false) -> StartResult {
        let chosen: Preset?
        if let name, !name.isEmpty {
            chosen = preset(named: name)
        } else {
            chosen = currentPreset ?? presets.first
        }
        guard let chosen else {
            record(.init(source: source, outcome: .refusedUnknownPreset, presetName: name))
            return .unknownPreset(name ?? "")
        }
        return start(chosen, source: source, fadeIn: fadeIn, minutes: minutes, ignoreWindow: ignoreWindow)
    }

    public func stop(source: TriggerSource, fadeOut: Double? = nil) {
        guard isPlaying else { return }
        let fade = fadeOut ?? currentPreset?.fadeOutSeconds ?? 0
        stopTimer?.invalidate(); stopTimer = nil
        stopAt = nil
        let name = currentPreset?.name
        record(.init(source: source, outcome: .stopped, presetName: name))
        if fade > 0 {
            fadeMaster(to: 0, over: fade) { [weak self] in self?.finishStop() }
        } else {
            finishStop()
        }
    }

    private func finishStop() {
        backend.stop()
        isPlaying = false
        stopAt = nil
        fadeTimer?.invalidate(); fadeTimer = nil
    }

    public func toggle(source: TriggerSource) {
        if isPlaying { stop(source: source) } else { start(named: nil, source: source) }
    }

    /// Live volume change from the slider while playing.
    public func setMasterVolume(_ volume: Double) {
        fadeTimer?.invalidate(); fadeTimer = nil
        liveMasterVolume = min(max(volume, 0), 1)
        backend.setMasterVolume(Float(liveMasterVolume))
    }

    // MARK: Fades and auto-stop

    /// A fade is just the master volume walked toward a target in small steps.
    private func fadeMaster(to target: Double, over seconds: Double, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        targetMasterVolume = target
        guard seconds > 0 else {
            liveMasterVolume = target
            backend.setMasterVolume(Float(target))
            completion?()
            return
        }
        let stepInterval = 0.05
        let steps = max(Int(seconds / stepInterval), 1)
        let delta = (target - liveMasterVolume) / Double(steps)
        var done = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                done += 1
                self.liveMasterVolume = done >= steps ? target : self.liveMasterVolume + delta
                self.backend.setMasterVolume(Float(self.liveMasterVolume))
                if done >= steps {
                    timer.invalidate()
                    self.fadeTimer = nil
                    completion?()
                }
            }
        }
    }

    private func scheduleAutoStop(minutes: Int?, from now: Date) {
        stopTimer?.invalidate(); stopTimer = nil
        guard let minutes, minutes > 0 else { stopAt = nil; return }
        let when = now.addingTimeInterval(TimeInterval(minutes * 60))
        stopAt = when
        stopTimer = Timer.scheduledTimer(withTimeInterval: when.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop(source: .autoStop) }
        }
    }

    // MARK: Scheduler

    private func fire(_ due: ScheduleEngine.Due) {
        switch due.rule.action {
        case .start(let presetID):
            guard let preset = preset(id: presetID) else {
                record(.init(source: .schedule, outcome: .refusedUnknownPreset, detail: due.rule.name))
                return
            }
            start(preset, source: .schedule)
        case .stop:
            stop(source: .schedule)
        }
    }

    public func setSchedulerRunning(_ on: Bool) {
        if on { runner.start() } else { runner.stop() }
    }

    // MARK: Network endpoint

    /// Handles one request from the local-network listener.
    public func handle(_ request: ControlRequest) -> ControlResponse {
        guard let command = request.command else {
            return .error(404, "Unknown path. Try /start, /stop, /status or /presets.")
        }
        guard request.token == settings.controlToken else {
            record(.init(source: .network, outcome: .refusedBadToken, detail: request.path))
            return .error(401, "Bad or missing token.")
        }
        switch command {
        case .start(let name, let fade, let minutes, let ignoreWindow):
            let result = start(named: name, source: .network, fadeIn: fade, minutes: minutes, ignoreWindow: ignoreWindow)
            let ok: Bool
            if case .started = result { ok = true } else if case .alreadyPlaying = result { ok = true } else { ok = false }
            return .json(ok ? 200 : 409, ["ok": ok, "message": result.message] .merging(statusDictionary()) { a, _ in a })
        case .stop(let fade):
            stop(source: .network, fadeOut: fade)
            return .ok(["ok": true, "message": "Stopped."].merging(statusDictionary()) { a, _ in a })
        case .status:
            return .ok(statusDictionary())
        case .presets:
            return .ok(["presets": presets.map { $0.name }])
        }
    }

    public func statusDictionary() -> [String: Any] {
        var d: [String: Any] = ["playing": isPlaying, "volume": liveMasterVolume]
        if let p = currentPreset { d["preset"] = p.name }
        if let s = stopAt { d["stopAt"] = ISO8601DateFormatter().string(from: s) }
        return d
    }

    // MARK: Log

    private func record(_ event: TriggerEvent) {
        log.append(event)
    }

    public func clearLog() { log.clear() }

    // MARK: Presets

    public func upsert(_ preset: Preset) {
        if let i = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[i] = preset
            if currentPreset?.id == preset.id { currentPreset = preset }
        } else {
            presets.append(preset)
        }
    }

    public func delete(presetID: UUID) {
        presets.removeAll { $0.id == presetID }
        schedules.removeAll { if case .start(let id) = $0.action { return id == presetID } else { return false } }
    }

    public func regenerateToken() {
        settings.controlToken = ControlToken.generate()
    }
}
