import Foundation
import Testing

@testable import VoiceInput

/// Path to the mock echo server script used for testing.
private let echoServerPath: String = {
    let thisFile = URL(fileURLWithPath: #filePath)
    return thisFile
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/echo_server.py")
        .path()
}()

/// Find a working Python executable.
private func pythonURL() -> URL {
    for path in ["/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3"] {
        if FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
    }
    return URL(fileURLWithPath: "/usr/bin/env")
}

private func pythonArguments() -> [String] {
    let url = pythonURL()
    if url.lastPathComponent == "env" {
        return ["python3", echoServerPath]
    }
    return [echoServerPath]
}

/// Mock command resolver that launches the echo_server.py mock instead of the real backend.
private struct MockCommandResolver: BackendCommandResolver {
    func resolve() throws -> BackendCommand_Launch {
        BackendCommand_Launch(
            executableURL: pythonURL(),
            arguments: pythonArguments()
        )
    }
}

@Suite("BackendManager")
@MainActor
struct BackendManagerTests {

    @Test(.timeLimit(.minutes(1)))
    func launchTransitionsToReady() async throws {
        let manager = BackendManager(commandResolver: MockCommandResolver())
        #expect(manager.state == .idle)

        try await manager.launch()
        #expect(manager.state == .ready)

        await manager.shutdown()
    }

    @Test(.timeLimit(.minutes(1)))
    func startAndStopListening() async throws {
        let manager = BackendManager(commandResolver: MockCommandResolver())
        try await manager.launch()
        #expect(manager.state == .ready)

        try manager.startListening()
        #expect(manager.state == .listening)

        try manager.stopListening()
        #expect(manager.state == .ready)

        await manager.shutdown()
    }

    @Test(.timeLimit(.minutes(1)))
    func startListeningReceivesTranscription() async throws {
        let manager = BackendManager(commandResolver: MockCommandResolver())
        try await manager.launch()

        try manager.startListening()

        // The mock server sends transcription events after "start" command.
        // Wait for the transcription to appear.
        let deadline = ContinuousClock.now + .seconds(5)
        while manager.currentTranscription.isEmpty {
            if ContinuousClock.now > deadline { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(manager.currentTranscription == "テスト")

        await manager.shutdown()
    }

    @Test(.timeLimit(.minutes(1)))
    func shutdownFromIdle() async throws {
        let manager = BackendManager(commandResolver: MockCommandResolver())
        // Should not crash when shutting down without launching
        await manager.shutdown()
        #expect(manager.state == .idle)
    }

    @Test(.timeLimit(.minutes(1)))
    func launchWhileRunningIsIgnored() async throws {
        let manager = BackendManager(commandResolver: MockCommandResolver())
        try await manager.launch()
        #expect(manager.state == .ready)

        // Second launch should be a no-op (already running)
        try await manager.launch()
        #expect(manager.state == .ready)

        await manager.shutdown()
    }

    @Test
    func startListeningInWrongState() async throws {
        let manager = BackendManager(commandResolver: MockCommandResolver())
        // Should not throw — just logs a warning and does nothing
        try manager.startListening()
        #expect(manager.state == .idle)
    }

    @Test
    func stopListeningInWrongState() async throws {
        let manager = BackendManager(commandResolver: MockCommandResolver())
        // Should not throw — just logs a warning and does nothing
        try manager.stopListening()
        #expect(manager.state == .idle)
    }

    @Test(.timeLimit(.minutes(1)))
    func stopListeningClearsTranscription() async throws {
        let manager = BackendManager(commandResolver: MockCommandResolver())
        try await manager.launch()
        try manager.startListening()

        // Wait for transcription
        let deadline = ContinuousClock.now + .seconds(5)
        while manager.currentTranscription.isEmpty {
            if ContinuousClock.now > deadline { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(!manager.currentTranscription.isEmpty)

        try manager.stopListening()
        #expect(manager.currentTranscription.isEmpty)

        await manager.shutdown()
    }
}
