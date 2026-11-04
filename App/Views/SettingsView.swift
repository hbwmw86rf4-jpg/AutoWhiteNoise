import SwiftUI
import NoiseCore

struct SettingsView: View {
    @Environment(PlayerController.self) private var controller
    @Environment(AppServices.self) private var services

    var body: some View {
        @Bindable var controller = controller
        Form {
            Section("Playback") {
                Toggle("Mix with other audio", isOn: $controller.settings.mixWithOthers)
                Text("Off: the app takes over audio and shows on the lock screen. On: music or podcasts keep playing underneath. Takes effect on the next start.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Scheduler") {
                Toggle("Run schedules in this app", isOn: $controller.settings.schedulerEnabled)
            }
            Section("Local network") {
                Toggle("Listen for requests", isOn: $controller.settings.controlEnabled)
                TextField("Port", value: $controller.settings.controlPort, format: .number)
                LabeledContent("Token") {
                    Text(controller.settings.controlToken).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                }
                Button("Generate a new token") { controller.regenerateToken() }
                LabeledContent("Status", value: services.serverStatus)
            }
            Section("Display") {
                Toggle("Appliance mode", isOn: $controller.settings.applianceMode)
            }
        }
        .formStyle(.grouped)
        .onChange(of: controller.settings) { _, _ in services.applySettings() }
        .navigationTitle("Settings")
    }
}
