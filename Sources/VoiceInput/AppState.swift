/// Central application state coordinating BackendManager, HotkeyManager, and TextInserter.
///
/// Provides a unified observable state for the UI and wires up the flow:
/// hotkey toggle → start/stop listening → final transcription → text insertion.

import Foundation
import os

@MainActor
@Observable
final class AppState {
    /// Unified application state.
    enum State: Sendable, Equatable {
        case idle
        case starting
        case ready
        case listening
        case error(String)
    }

    // MARK: - Observable properties

    /// Current application state.
    private(set) var state: State = .idle

    /// The latest transcription text (partial or final).
    private(set) var currentTranscription: String = ""

    /// Whether Accessibility permission has been granted.
    var isAccessibilityGranted: Bool {
        textInserter.isAccessibilityGranted
    }

    /// Whether the global hotkey is registered.
    var isHotkeyRegistered: Bool {
        hotkeyManager.isRegistered
    }

    // MARK: - Managers

    let backendManager: BackendManager
    let hotkeyManager: HotkeyManager
    let textInserter: TextInserter

    // MARK: - Internal

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.speak-pilot",
        category: "AppState"
    )

    /// Serializes text insertion to prevent clipboard interleaving.
    private var insertionTask: Task<Void, Never>?

    // MARK: - Init

    init(
        backendManager: BackendManager = BackendManager(),
        hotkeyManager: HotkeyManager = HotkeyManager(),
        textInserter: TextInserter = TextInserter()
    ) {
        self.backendManager = backendManager
        self.hotkeyManager = hotkeyManager
        self.textInserter = textInserter

        wireUpCallbacks()
    }

    // MARK: - Public API

    /// Set up all subsystems: launch backend, register hotkey, check accessibility.
    ///
    /// Can be called from `.idle` or `.error` state to (re-)initialize.
    func setup() async {
        guard state == .idle || isErrorState else {
            logger.warning("setup() called in state \(String(describing: self.state))")
            return
        }

        textInserter.checkAccessibility(prompt: true)

        if !isAccessibilityGranted {
            logger.warning("Accessibility permission not granted")
        }

        hotkeyManager.register()

        do {
            state = .starting
            try await backendManager.launch()
            state = .ready
            logger.info("Setup complete")
        } catch {
            state = .error(error.localizedDescription)
            logger.error("Setup failed: \(error)")
        }
    }

    /// Toggle listening on/off.
    func toggleListening() {
        switch state {
        case .ready:
            do {
                try backendManager.startListening()
                state = .listening
                currentTranscription = ""
                logger.info("Listening started")
            } catch {
                state = .error(error.localizedDescription)
                logger.error("Failed to start listening: \(error)")
            }
        case .listening:
            do {
                try backendManager.stopListening()
                state = .ready
                currentTranscription = ""
                logger.info("Listening stopped")
            } catch {
                state = .error(error.localizedDescription)
                logger.error("Failed to stop listening: \(error)")
            }
        default:
            logger.warning(
                "toggleListening() called in state \(String(describing: self.state))")
        }
    }

    /// Gracefully shut down all subsystems.
    func shutdown() async {
        hotkeyManager.unregister()
        await backendManager.shutdown()
        state = .idle
        currentTranscription = ""
        logger.info("Shutdown complete")
    }

    // MARK: - Private

    private var isErrorState: Bool {
        if case .error = state { return true }
        return false
    }

    private func wireUpCallbacks() {
        hotkeyManager.onToggle = { [weak self] in
            self?.toggleListening()
        }

        backendManager.onPartialTranscription = { [weak self] text in
            guard let self else { return }
            self.currentTranscription = text
        }

        backendManager.onFinalTranscription = { [weak self] text in
            guard let self else { return }
            self.handleFinalTranscription(text)
        }
    }

    private func handleFinalTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        currentTranscription = trimmed

        guard isAccessibilityGranted else {
            logger.warning(
                "Skipping text insertion: Accessibility not granted")
            return
        }

        let previousTask = insertionTask
        insertionTask = Task {
            await previousTask?.value
            do {
                try await textInserter.insertText(trimmed)
                logger.info("Inserted transcription (\(trimmed.count) chars)")
            } catch {
                logger.error("Text insertion failed: \(error)")
            }
        }
    }
}
