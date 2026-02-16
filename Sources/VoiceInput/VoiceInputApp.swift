import SwiftUI

@main
struct VoiceInputApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("SpeakPilot", systemImage: menuBarIcon) {
            ContentView(appState: appState)
        }
    }

    private var menuBarIcon: String {
        switch appState.state {
        case .idle:
            "mic"
        case .starting:
            "waveform"
        case .ready:
            "mic"
        case .listening:
            "mic.fill"
        case .error:
            "mic.slash"
        }
    }
}
