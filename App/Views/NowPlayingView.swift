import SwiftUI
import NoiseCore

struct NowPlayingView: View {
    @Environment(PlayerController.self) private var controller
    @Environment(AppServices.self) private var services
    @State private var selectedPresetID: UUID?
    @State private var stopAfterMinutes: Int = 0

    private var selectedPreset: Preset? {
        controller.preset(id: selectedPresetID ?? UUID()) ?? controller.currentPreset ?? controller.presets.first
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image(systemName: controller.isPlaying ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 96, weight: .thin))
                .foregroundStyle(controller.isPlaying ? Color.accentColor : .secondary)
                .symbolEffect(.variableColor.iterative, isActive: controller.isPlaying)

            VStack(spacing: 4) {
                Text(controller.isPlaying ? (controller.currentPreset?.name ?? "Playing") : "Stopped")
                    .font(.title.weight(.semibold))
                if controller.isPlaying, let stopAt = controller.stopAt {
                    Text("Stops at \(stopAt, style: .time)").foregroundStyle(.secondary)
                } else if controller.isPlaying, let src = controller.lastStartSource {
                    Text("Started by \(src.displayName.lowercased())").foregroundStyle(.secondary)
                } else if let next = ScheduleEngine.nextFire(controller.schedules, after: Date()) {
                    Text("Next schedule: \(next.0.name) at \(next.1, style: .time)").foregroundStyle(.secondary)
                }
            }

            Picker("Preset", selection: Binding(
                get: { selectedPreset?.id ?? UUID() },
                set: { selectedPresetID = $0 })) {
                ForEach(controller.presets) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(controller.isPlaying)

            Button {
                if controller.isPlaying {
                    controller.stop(source: .manual)
                } else if let preset = selectedPreset {
                    controller.start(preset, source: .manual, minutes: stopAfterMinutes > 0 ? stopAfterMinutes : nil)
                }
            } label: {
                Label(controller.isPlaying ? "Stop" : "Start", systemImage: controller.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: 260)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: Binding(
                        get: { controller.isPlaying ? controller.liveMasterVolume : (selectedPreset?.masterVolume ?? 0.7) },
                        set: { v in
                            if controller.isPlaying { controller.setMasterVolume(v) }
                            else if var p = selectedPreset { p.masterVolume = v; controller.upsert(p) }
                        }), in: 0...1)
                    Image(systemName: "speaker.wave.3.fill")
                }
                Picker("Stop after", selection: $stopAfterMinutes) {
                    Text("Preset default").tag(0)
                    Text("30 min").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("4 hours").tag(240)
                    Text("8 hours").tag(480)
                }
                .disabled(controller.isPlaying)
            }
            .frame(maxWidth: 420)

            if let error = controller.lastError {
                Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Now Playing")
        .toolbar {
            ToolbarItem {
                Button {
                    controller.settings.applianceMode = true
                    services.applySettings()
                } label: {
                    Label("Appliance mode", systemImage: "moon.zzz")
                }
                .help("Dim the screen, keep the device awake, and show a clock. For a bedside iPad or Mac.")
            }
        }
    }
}
