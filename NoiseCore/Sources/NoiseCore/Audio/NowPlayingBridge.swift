#if canImport(MediaPlayer)
import Foundation
import MediaPlayer

/// Puts the current preset on the lock screen / Control Center / Mac menu bar
/// "Now Playing" widget and wires its play/pause/stop buttons to the player.
/// Without this, iOS shows nothing while we play and offers no way to stop us
/// short of opening the app.
@MainActor
public final class NowPlayingBridge {
    private let controller: PlayerController
    private var installed = false

    public init(controller: PlayerController) {
        self.controller = controller
    }

    public func install() {
        guard !installed else { return }
        installed = true
        let center = MPRemoteCommandCenter.shared()
        // The command handlers are invoked on the main thread, but the compiler
        // cannot see that, so each one asserts main-actor isolation explicitly.
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.controller.start(named: nil, source: .remote) }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.controller.stop(source: .remote) }
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.controller.stop(source: .remote) }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.controller.toggle(source: .remote) }
            return .success
        }
        // Skip/seek make no sense for endless noise; disable so the UI hides them.
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
    }

    /// Call whenever playback state or preset changes.
    public func refresh() {
        let center = MPNowPlayingInfoCenter.default()
        guard controller.isPlaying, let preset = controller.currentPreset else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: preset.name,
            MPMediaItemPropertyArtist: "AutoWhiteNoise",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        if let stopAt = controller.stopAt {
            info[MPMediaItemPropertyPlaybackDuration] = stopAt.timeIntervalSinceNow
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        }
        center.nowPlayingInfo = info
        center.playbackState = .playing
    }
}
#endif
