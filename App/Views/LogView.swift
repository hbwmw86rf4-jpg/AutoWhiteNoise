import SwiftUI
import NoiseCore

struct LogView: View {
    @Environment(PlayerController.self) private var controller

    var body: some View {
        List {
            if controller.log.events.isEmpty {
                Text("Nothing yet. Every start and stop, and every refused request, shows up here with what caused it.")
                    .foregroundStyle(.secondary)
            }
            ForEach(controller.log.events) { event in
                HStack(alignment: .top) {
                    Image(systemName: symbol(for: event.outcome))
                        .foregroundStyle(color(for: event.outcome))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(label(for: event.outcome)) \(event.presetName ?? "")")
                            .font(.body)
                        Text("\(event.source.displayName) · \(event.date, format: .dateTime.weekday().month().day().hour().minute())\(event.detail.map { " · " + $0 } ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Log")
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) { controller.clearLog() } label: { Label("Clear", systemImage: "trash") }
                    .disabled(controller.log.events.isEmpty)
            }
        }
    }

    private func label(for o: TriggerOutcome) -> String {
        switch o {
        case .started: return "Started"
        case .stopped: return "Stopped"
        case .refusedOutsideWindow: return "Refused (outside allowed hours)"
        case .refusedUnknownPreset: return "Refused (unknown preset)"
        case .refusedBadToken: return "Refused (bad token)"
        case .failed: return "Failed"
        }
    }

    private func symbol(for o: TriggerOutcome) -> String {
        switch o {
        case .started: return "play.circle.fill"
        case .stopped: return "stop.circle"
        case .refusedOutsideWindow, .refusedUnknownPreset, .refusedBadToken: return "hand.raised.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private func color(for o: TriggerOutcome) -> Color {
        switch o {
        case .started: return .accentColor
        case .stopped: return .secondary
        case .refusedOutsideWindow, .refusedUnknownPreset, .refusedBadToken: return .orange
        case .failed: return .red
        }
    }
}
