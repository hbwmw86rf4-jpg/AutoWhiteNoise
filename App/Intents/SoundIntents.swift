import AppIntents
import NoiseCore

/// "Start Sound". Adopting AudioPlaybackIntent tells iOS this intent plays
/// audio, which is what allows the app to be launched in the background by a
/// Shortcuts automation and start the audio session with the screen locked.
struct StartSoundIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Start Sound"
    static var description = IntentDescription(
        "Starts a white-noise preset. Works from Shortcuts automations, Siri, the Action Button and widgets.",
        categoryName: "Playback")
    /// false = do not bring the app to the front. Essential for night use.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Preset", description: "Leave empty for the last-used preset.")
    var preset: PresetEntity?

    @Parameter(title: "Fade in (seconds)", description: "Leave empty to use the preset's own fade.")
    var fadeInSeconds: Double?

    @Parameter(title: "Stop after (minutes)", description: "Leave empty to use the preset's own setting.")
    var stopAfterMinutes: Int?

    @Parameter(title: "Ignore allowed hours",
               description: "Start even if the preset's allowed hours say no.", default: false)
    var ignoreAllowedHours: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$preset)") {
            \.$fadeInSeconds
            \.$stopAfterMinutes
            \.$ignoreAllowedHours
        }
    }

    @Dependency var controller: PlayerController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result: StartResult
        if let preset, let found = controller.preset(id: preset.id) {
            result = controller.start(found, source: .shortcut, fadeIn: fadeInSeconds,
                                      minutes: stopAfterMinutes, ignoreWindow: ignoreAllowedHours)
        } else {
            result = controller.start(named: nil, source: .shortcut, fadeIn: fadeInSeconds,
                                      minutes: stopAfterMinutes, ignoreWindow: ignoreAllowedHours)
        }
        if case .failed(let why) = result {
            throw IntentError.failed(why)
        }
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

struct StopSoundIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Stop Sound"
    static var description = IntentDescription("Stops playback, with the preset's fade-out.", categoryName: "Playback")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Fade out (seconds)", description: "Leave empty to use the preset's own fade.")
    var fadeOutSeconds: Double?

    @Dependency var controller: PlayerController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let wasPlaying = controller.isPlaying
        controller.stop(source: .shortcut, fadeOut: fadeOutSeconds)
        return .result(dialog: wasPlaying ? "Stopping." : "Nothing was playing.")
    }
}

struct ToggleSoundIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Toggle Sound"
    static var description = IntentDescription("Starts the last preset if stopped, stops if playing. Good for the Action Button.", categoryName: "Playback")
    static var openAppWhenRun: Bool = false

    @Dependency var controller: PlayerController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        controller.toggle(source: .shortcut)
        return .result(dialog: controller.isPlaying ? "Started." : "Stopped.")
    }
}

/// Lets a shortcut branch on whether we are playing ("if playing, do nothing").
struct IsPlayingIntent: AppIntent {
    static var title: LocalizedStringResource = "Is Sound Playing"
    static var description = IntentDescription("Returns whether a preset is currently playing.", categoryName: "Playback")
    static var openAppWhenRun: Bool = false

    @Dependency var controller: PlayerController

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: controller.isPlaying)
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case failed(String)
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .failed(let why): return "Could not start: \(why)"
        }
    }
}

/// Pre-made shortcuts that appear in the Shortcuts app and Spotlight as soon
/// as the app is installed, with Siri phrases.
struct AutoWhiteNoiseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSoundIntent(),
            phrases: ["Start \(.applicationName)", "Turn on \(.applicationName)", "Play \(.applicationName)"],
            shortTitle: "Start sound",
            systemImageName: "play.circle.fill")
        AppShortcut(
            intent: StopSoundIntent(),
            phrases: ["Stop \(.applicationName)", "Turn off \(.applicationName)"],
            shortTitle: "Stop sound",
            systemImageName: "stop.circle.fill")
        AppShortcut(
            intent: ToggleSoundIntent(),
            phrases: ["Toggle \(.applicationName)"],
            shortTitle: "Toggle sound",
            systemImageName: "playpause.circle.fill")
    }
}
