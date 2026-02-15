import Foundation
import Testing

@testable import VoiceInput

@Suite("AppState")
@MainActor
struct AppStateTests {

    @Test
    func initialState() async throws {
        let appState = AppState()
        #expect(appState.state == .idle)
        #expect(appState.currentTranscription.isEmpty)
        #expect(!appState.isHotkeyRegistered)
    }

    @Test
    func toggleListeningInIdleState() async throws {
        let appState = AppState()
        // Should not crash — logs a warning and does nothing.
        appState.toggleListening()
        #expect(appState.state == .idle)
    }

    @Test
    func shutdownFromIdle() async throws {
        let appState = AppState()
        await appState.shutdown()
        #expect(appState.state == .idle)
        #expect(appState.currentTranscription.isEmpty)
    }

    @Test
    func managersAreAccessible() async throws {
        let backend = BackendManager()
        let hotkey = HotkeyManager()
        let inserter = TextInserter()

        let appState = AppState(
            backendManager: backend,
            hotkeyManager: hotkey,
            textInserter: inserter
        )

        #expect(appState.backendManager === backend)
        #expect(appState.hotkeyManager === hotkey)
        #expect(appState.textInserter === inserter)
    }

    @Test
    func hotkeyCallbackIsWired() async throws {
        let appState = AppState()
        // onToggle should be set by AppState's wireUpCallbacks.
        #expect(appState.hotkeyManager.onToggle != nil)
    }

    @Test
    func finalTranscriptionCallbackIsWired() async throws {
        let appState = AppState()
        // onFinalTranscription should be set by AppState's wireUpCallbacks.
        #expect(appState.backendManager.onFinalTranscription != nil)
    }
}
