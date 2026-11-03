import SwiftUI
import NoiseCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Step-by-step recipes for the ways the app can be started without a tap.
/// Apps cannot create Shortcuts automations on the user's behalf, so this
/// screen is the next best thing: exact steps, and a copy button for the
/// network URL.
struct AutomationsView: View {
    @Environment(PlayerController.self) private var controller
    @Environment(AppServices.self) private var services
    @State private var copied = false

    var body: some View {
        List {
            Section {
                recipe(
                    title: "Start at a set time (iPhone / iPad)",
                    symbol: "clock",
                    steps: [
                        "Open Shortcuts → Automation → + → Time of Day.",
                        "Pick the time and days. Choose Run Immediately. Tap Next.",
                        "Search for AutoWhiteNoise and add Start Sound. Pick a preset.",
                        "Done. The app launches in the background and plays with the screen locked.",
                    ])
                recipe(
                    title: "Start when my wife wakes up",
                    symbol: "person.2",
                    steps: [
                        "On HER phone: Shortcuts → Automation → + → Charger → Is Disconnected → Run Immediately.",
                        "Actions: Get Current Date → Format Date (custom format HH) → If Formatted Date is between 5 and 8 → Send Message \"wn:start\" to you. (Or use the Alarm → Is Stopped trigger.)",
                        "On YOUR phone: Shortcuts → Automation → + → Message → Sender: her, Message Contains: wn:start → Run Immediately.",
                        "Action: AutoWhiteNoise → Start Sound, preset of your choice. Set the preset's allowed hours as a second safety net.",
                    ])
                recipe(
                    title: "Stop at a set time",
                    symbol: "stop.circle",
                    steps: [
                        "Shortcuts → Automation → + → Time of Day → Run Immediately.",
                        "Action: AutoWhiteNoise → Stop Sound.",
                        "Or give the preset a Stop automatically value and skip this.",
                    ])
                recipe(
                    title: "Action Button, Siri, Control Center",
                    symbol: "button.programmable",
                    steps: [
                        "Say \"Start AutoWhiteNoise\" or \"Stop AutoWhiteNoise\" to Siri; it works as soon as the app is installed.",
                        "Settings → Action Button → Shortcut → Toggle Sound.",
                        "Add the Start Sound shortcut to Control Center or the Lock Screen from the Shortcuts app.",
                    ])
            } header: { Text("Shortcuts") }

            Section {
                Toggle("Listen for requests on this Wi-Fi", isOn: Binding(
                    get: { controller.settings.controlEnabled },
                    set: { controller.settings.controlEnabled = $0; services.applySettings() }))
                LabeledContent("Status", value: services.serverStatus)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Example start URL").font(.caption).foregroundStyle(.secondary)
                    Text(services.exampleStartURL)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    HStack {
                        Button(copied ? "Copied" : "Copy URL") {
                            copyToPasteboard(services.exampleStartURL)
                            copied = true
                            Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
                        }
                        Button("Test now") {
                            _ = controller.handle(ControlRequest(method: "GET", path: "/start",
                                                                 query: ["preset": controller.presets.first?.name ?? "", "token": controller.settings.controlToken]))
                        }
                    }
                    .buttonStyle(.bordered)
                }
                recipe(
                    title: "From another phone on the same Wi-Fi",
                    symbol: "wifi",
                    steps: [
                        "Any Shortcuts automation on her phone → action Get Contents of URL → paste the URL above.",
                        "Paths: /start?preset=NAME  /stop  /status  /presets. Add &minutes=90 or &fade=20 to override. Add &force=1 to ignore allowed hours.",
                        "Works whenever this app is running: always on a Mac; on iPhone/iPad only while the app is open, in appliance mode, or already playing.",
                    ])
                recipe(
                    title: "From a smart-home hub (HomeKit / Matter / Home Assistant)",
                    symbol: "homekit",
                    steps: [
                        "Home app → Automation → when an accessory turns on (a smart plug under a fan, a motion sensor) → Convert to Shortcut → Get Contents of URL → the URL above.",
                        "Hub automations cannot call third-party apps directly, which is why the URL exists.",
                        "Best with a Mac or a plugged-in iPad in appliance mode, so the listener is always up.",
                    ])
            } header: { Text("Local network") } footer: {
                Text("The token is a password. Anyone on your Wi-Fi who has it can start or stop playback. Change it in Settings.")
            }

            Section {
                recipe(
                    title: "No app at all: Apple's Background Sounds",
                    symbol: "ear",
                    steps: [
                        "iOS has built-in white, pink, brown, ocean, rain and stream sounds under Settings → Accessibility → Audio & Visual → Background Sounds.",
                        "Any of the automations above can use the Set Background Sound and Set Background Sounds actions instead of this app.",
                        "Useful as a fallback, and for testing the trigger plumbing.",
                    ])
            } header: { Text("Also worth knowing") }
        }
        .navigationTitle("Automations")
    }

    private func recipe(title: String, symbol: String, steps: [String]) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).").monospacedDigit().foregroundStyle(.secondary)
                        Text(step)
                    }
                    .font(.callout)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label(title, systemImage: symbol)
        }
    }

    private func copyToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
