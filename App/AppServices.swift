import Foundation
import Observation
import NoiseCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Owns the controller plus the platform services around it: the lock-screen
/// media bridge, the local-network listener, the scheduler, and appliance
/// mode (screen awake). One instance for the life of the app.
@MainActor
@Observable
final class AppServices {
    let controller: PlayerController
    @ObservationIgnored private let engine: NoiseEngine
    @ObservationIgnored private let nowPlaying: NowPlayingBridge
    @ObservationIgnored private var server: LocalControlServer?
    @ObservationIgnored private var sleepActivity: NSObjectProtocol?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private(set) var serverStatus: String = "Off"
    /// Fallback host for the example URL. On iOS, `ProcessInfo.hostName` does a
    /// blocking reverse-DNS lookup that can stall the main thread for seconds,
    /// so it is only read on the Mac.
    private(set) var hostName: String = {
        #if os(macOS)
        return ProcessInfo.processInfo.hostName
        #else
        return "this-device.local"
        #endif
    }()

    init() {
        let engine = NoiseEngine()
        self.engine = engine
        let controller = PlayerController(backend: engine, storage: Storage.standard())
        self.controller = controller
        self.nowPlaying = NowPlayingBridge(controller: controller)
        engine.mixWithOthers = controller.settings.mixWithOthers
        nowPlaying.install()
        trackPlayback()
        installPlatformObservers()
        applySettings()
    }

    /// Re-reads settings and starts/stops the services they govern. Call after
    /// any settings change.
    func applySettings() {
        engine.mixWithOthers = controller.settings.mixWithOthers
        controller.setSchedulerRunning(controller.settings.schedulerEnabled)
        if controller.settings.controlEnabled {
            startServer()
        } else {
            stopServer()
        }
        setKeepAwake(controller.settings.applianceMode)
    }

    func didBecomeActive() {
        // Catch up on anything missed while suspended (iPhone) or asleep (Mac).
        controller.runner.tick()
        #if os(macOS)
        hostName = ProcessInfo.processInfo.hostName
        #endif
        applySettings()
    }

    // MARK: Lock screen / Control Center

    /// Observation lets us react to controller changes without Combine: the
    /// closure re-registers itself after each change.
    private func trackPlayback() {
        withObservationTracking {
            _ = controller.isPlaying
            _ = controller.currentPreset
            _ = controller.stopAt
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.nowPlaying.refresh()
                self.trackPlayback()
            }
        }
    }

    // MARK: Local network endpoint

    private func startServer() {
        let port = controller.settings.controlPort
        if let server, server.isRunning, server.port == port { return }
        stopServer()
        let s = LocalControlServer { [weak self] request in
            self?.controller.handle(request) ?? .error(503, "Not ready")
        }
        s.onStateChange = { [weak self] text in
            Task { @MainActor in self?.serverStatus = text }
        }
        do {
            try s.start(port: port)
            server = s
            serverStatus = "Starting…"
        } catch {
            serverStatus = "Failed: \(error.localizedDescription)"
        }
    }

    private func stopServer() {
        server?.stop()
        server = nil
        serverStatus = "Off"
    }

    /// The URL another device would call. Uses the numeric Wi-Fi address because
    /// `<name>.local` does not resolve from every device; the address only
    /// changes if the router hands out a new one, so pin a DHCP reservation.
    var exampleStartURL: String {
        let host = LocalNetworkInfo.primaryIPv4Address() ?? hostName
        let preset = controller.presets.first?.name ?? "Rain"
        return "http://\(host):\(controller.settings.controlPort)/start?preset=\(preset)&token=\(controller.settings.controlToken)"
    }

    // MARK: Appliance mode

    private func setKeepAwake(_ on: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = on
        #elseif os(macOS)
        if on, sleepActivity == nil {
            sleepActivity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled, .userInitiated],
                reason: "AutoWhiteNoise appliance mode")
        } else if !on, let activity = sleepActivity {
            ProcessInfo.processInfo.endActivity(activity)
            sleepActivity = nil
        }
        #endif
    }

    private func installPlatformObservers() {
        #if os(macOS)
        // After the Mac wakes, check whether a schedule came due while asleep.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.controller.runner.tick() }
            })
        #endif
    }
}
