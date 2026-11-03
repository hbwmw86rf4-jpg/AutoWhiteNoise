import SwiftUI
import NoiseCore

#if os(macOS)
struct MenuBarContent: View {
    @Environment(PlayerController.self) private var controller

    var body: some View {
        if controller.isPlaying {
            Text("Playing \(controller.currentPreset?.name ?? "")")
            Button("Stop") { controller.stop(source: .manual) }
        } else {
            Text("Stopped")
        }
        Divider()
        ForEach(controller.presets) { preset in
            Button(preset.name) { controller.start(preset, source: .manual) }
        }
        Divider()
        Button("Quit AutoWhiteNoise") { NSApplication.shared.terminate(nil) }
    }
}
#endif
