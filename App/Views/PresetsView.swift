import SwiftUI
import NoiseCore

struct PresetsView: View {
    @Environment(PlayerController.self) private var controller
    @State private var editing: Preset?

    var body: some View {
        List {
            ForEach(controller.presets) { preset in
                Button { editing = preset } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name).font(.headline)
                            Text(summary(for: preset)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if controller.currentPreset?.id == preset.id && controller.isPlaying {
                            Image(systemName: "waveform").foregroundStyle(Color.accentColor)
                        }
                        Button {
                            if controller.isPlaying && controller.currentPreset?.id == preset.id {
                                controller.stop(source: .manual)
                            } else {
                                controller.start(preset, source: .manual)
                            }
                        } label: {
                            Image(systemName: controller.isPlaying && controller.currentPreset?.id == preset.id ? "stop.circle" : "play.circle")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for i in offsets { controller.delete(presetID: controller.presets[i].id) }
            }
            .onMove { from, to in controller.presets.move(fromOffsets: from, toOffset: to) }
        }
        .navigationTitle("Presets")
        .toolbar {
            ToolbarItem {
                Button {
                    editing = Preset(name: "New preset", layers: [Layer(kind: .pink)])
                } label: { Label("Add", systemImage: "plus") }
            }
        }
        .sheet(item: $editing) { preset in
            PresetEditorView(preset: preset) { saved in controller.upsert(saved) }
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 560)
                #endif
        }
    }

    private func summary(for preset: Preset) -> String {
        var parts = [preset.layers.map(\.kind.displayName).joined(separator: " + ")]
        if let w = preset.allowedWindow { parts.append("auto only \(w.formatted)") }
        if let m = preset.autoStopMinutes { parts.append("stops after \(m) min") }
        return parts.joined(separator: " · ")
    }
}

struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var preset: Preset
    let onSave: (Preset) -> Void

    @State private var useWindow: Bool
    @State private var windowStart: Date
    @State private var windowEnd: Date
    @State private var useAutoStop: Bool
    @State private var autoStop: Int

    init(preset: Preset, onSave: @escaping (Preset) -> Void) {
        _preset = State(initialValue: preset)
        self.onSave = onSave
        _useWindow = State(initialValue: preset.allowedWindow != nil)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let s = preset.allowedWindow?.start ?? HourMinute(hour: 5, minute: 0)
        let e = preset.allowedWindow?.end ?? HourMinute(hour: 8, minute: 0)
        _windowStart = State(initialValue: cal.date(bySettingHour: s.hour, minute: s.minute, second: 0, of: today) ?? today)
        _windowEnd = State(initialValue: cal.date(bySettingHour: e.hour, minute: e.minute, second: 0, of: today) ?? today)
        _useAutoStop = State(initialValue: preset.autoStopMinutes != nil)
        _autoStop = State(initialValue: preset.autoStopMinutes ?? 120)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $preset.name)
                }
                Section {
                    ForEach($preset.layers) { $layer in
                        VStack(alignment: .leading) {
                            Picker("Sound", selection: $layer.kind) {
                                ForEach(SoundKind.allCases) { Text($0.displayName).tag($0) }
                            }
                            Slider(value: $layer.volume, in: 0...1) { Text("Volume") }
                            Text(layer.kind.blurb).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { preset.layers.remove(atOffsets: $0) }
                    if preset.layers.count < 3 {
                        Button("Add layer") { preset.layers.append(Layer(kind: .brown, volume: 0.4)) }
                    }
                } header: { Text("Layers (up to 3)") } footer: {
                    Text("Layers play at the same time. Mix a bright sound with a deep one for a fuller bed.")
                }
                Section("Levels and fades") {
                    LabeledSlider(title: "Master volume", value: $preset.masterVolume, range: 0...1, format: { "\(Int($0 * 100))%" })
                    LabeledSlider(title: "Fade in", value: $preset.fadeInSeconds, range: 0...60, format: { "\(Int($0)) s" })
                    LabeledSlider(title: "Fade out", value: $preset.fadeOutSeconds, range: 0...60, format: { "\(Int($0)) s" })
                }
                Section {
                    Toggle("Stop automatically", isOn: $useAutoStop)
                    if useAutoStop {
                        Stepper("After \(autoStop) min", value: $autoStop, in: 5...720, step: 5)
                    }
                }
                Section {
                    Toggle("Only allow automatic starts between", isOn: $useWindow)
                    if useWindow {
                        DatePicker("From", selection: $windowStart, displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: $windowEnd, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("Applies to Shortcuts, network and schedule starts. Tapping Start in the app always works. A window may cross midnight.")
                }
            }
            .navigationTitle(preset.name.isEmpty ? "Preset" : preset.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var p = preset
                        p.autoStopMinutes = useAutoStop ? autoStop : nil
                        p.allowedWindow = useWindow
                            ? TimeWindow(start: HourMinute(date: windowStart), end: HourMinute(date: windowEnd))
                            : nil
                        if p.layers.isEmpty { p.layers = [Layer(kind: .pink)] }
                        onSave(p)
                        dismiss()
                    }
                    .disabled(preset.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(title); Spacer(); Text(format(value)).foregroundStyle(.secondary).monospacedDigit() }
            Slider(value: $value, in: range)
        }
    }
}
