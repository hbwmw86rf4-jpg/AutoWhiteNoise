import SwiftUI
import AppIntents
import NoiseCore

/// App entry point. Builds the one PlayerController the whole app shares,
/// registers it with App Intents (so Shortcuts/Siri reach the same instance),
/// and hands it to the views through the SwiftUI environment.
@main
struct AutoWhiteNoiseApp: App {
    @State private var services: AppServices

    init() {
        let services = AppServices()
        _services = State(initialValue: services)
        // App Intents look dependencies up by type. Registering here, before any
        // intent can run, is what lets `@Dependency var controller` work.
        AppDependencyManager.shared.add(dependency: services.controller)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .environment(services.controller)
                .onAppear { services.didBecomeActive() }
        }
        .defaultSize(width: 760, height: 560)

        #if os(macOS)
        // A menu bar item so the Mac can sit closed-lid or in the background
        // and still be one click from start/stop.
        MenuBarExtra("AutoWhiteNoise", systemImage: services.controller.isPlaying ? "waveform" : "waveform.slash") {
            MenuBarContent()
                .environment(services)
                .environment(services.controller)
        }

        Settings {
            SettingsView()
                .environment(services)
                .environment(services.controller)
                .frame(width: 480)
        }
        #endif
    }
}
