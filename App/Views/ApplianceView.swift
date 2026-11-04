import SwiftUI
import Combine
import NoiseCore

/// Bedside mode: near-black screen, large dim clock, one big button, and the
/// device stays awake so the scheduler and the network listener keep running.
struct ApplianceView: View {
    @Environment(PlayerController.self) private var controller
    @Environment(AppServices.self) private var services
    @State private var now = Date()
    private let tick = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text(now, style: .time)
                    .font(.system(size: 110, weight: .thin, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .monospacedDigit()
                Text(statusLine)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.3))
                Button {
                    controller.toggle(source: .manual)
                } label: {
                    Image(systemName: controller.isPlaying ? "stop.circle" : "play.circle")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Exit appliance mode") {
                    controller.settings.applianceMode = false
                    services.applySettings()
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.25))
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
        }
        .onReceive(tick) { now = $0 }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        #endif
    }

    private var statusLine: String {
        if controller.isPlaying {
            var s = controller.currentPreset?.name ?? "Playing"
            if let stop = controller.stopAt { s += " · until " + stop.formatted(date: .omitted, time: .shortened) }
            return s
        }
        if let next = ScheduleEngine.nextFire(controller.schedules, after: now) {
            return "Next: \(next.0.name) at " + next.1.formatted(date: .omitted, time: .shortened)
        }
        return controller.settings.controlEnabled ? "Listening · " + services.serverStatus : "Idle"
    }
}
