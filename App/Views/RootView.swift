import SwiftUI
import NoiseCore

enum AppSection: String, CaseIterable, Identifiable {
    case nowPlaying = "Now Playing"
    case presets = "Presets"
    case schedules = "Schedules"
    case automations = "Automations"
    case log = "Log"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .nowPlaying: return "waveform"
        case .presets: return "slider.horizontal.3"
        case .schedules: return "clock"
        case .automations: return "bolt.horizontal"
        case .log: return "list.bullet.rectangle"
        }
    }
}

/// Tabs on iPhone/iPad, sidebar on Mac. Appliance mode replaces everything
/// with a dark clock screen.
struct RootView: View {
    @Environment(PlayerController.self) private var controller
    @State private var selection: AppSection? = .nowPlaying

    var body: some View {
        if controller.settings.applianceMode {
            ApplianceView()
        } else {
            #if os(macOS)
            NavigationSplitView {
                List(AppSection.allCases, selection: $selection) { section in
                    Label(section.rawValue, systemImage: section.symbol).tag(section)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            } detail: {
                detail(for: selection ?? .nowPlaying)
            }
            #else
            TabView {
                ForEach(AppSection.allCases) { section in
                    NavigationStack { detail(for: section) }
                        .tabItem { Label(section.rawValue, systemImage: section.symbol) }
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func detail(for section: AppSection) -> some View {
        switch section {
        case .nowPlaying: NowPlayingView()
        case .presets: PresetsView()
        case .schedules: SchedulesView()
        case .automations: AutomationsView()
        case .log: LogView()
        }
    }
}
