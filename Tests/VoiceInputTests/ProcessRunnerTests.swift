import Foundation
import Testing

@testable import VoiceInput

/// Path to the mock echo server script used for testing.
private let echoServerPath: String = {
    // Navigate from the build directory to the test fixtures
    let thisFile = URL(fileURLWithPath: #filePath)
    return thisFile
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/echo_server.py")
        .path()
}()

/// Find a working Python executable.
private func pythonURL() -> URL {
    // Try common locations
    for path in ["/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3"] {
        if FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
    }
    // Fallback: assume python3 is in PATH
    return URL(fileURLWithPath: "/usr/bin/env")
}

private func pythonArguments() -> [String] {
    let url = pythonURL()
    if url.lastPathComponent == "env" {
        return ["python3", echoServerPath]
    }
    return [echoServerPath]
}

@Suite("ProcessRunner")
struct ProcessRunnerTests {
    @Test func startAndReceiveReadyEvent() async throws {
        let runner = ProcessRunner()
        try runner.start(
            executableURL: pythonURL(),
            arguments: pythonArguments()
        )

        // Should receive "ready" event from mock server
        var receivedReady = false
        for await event in runner.events {
            if event == .ready {
                receivedReady = true
                break
            }
        }
        #expect(receivedReady)
        runner.terminate()
    }

    @Test func sendCommandAndReceiveEvents() async throws {
        let runner = ProcessRunner()
        try runner.start(
            executableURL: pythonURL(),
            arguments: pythonArguments()
        )

        // Wait for ready
        for await event in runner.events {
            if event == .ready { break }
        }

        // Send start command
        try runner.send(.start)

        // Collect events until speech_ended
        var events: [BackendEvent] = []
        for await event in runner.events {
            events.append(event)
            if event == .speechEnded { break }
        }

        #expect(events.contains(.speechStarted))
        #expect(events.contains(.transcription(text: "テスト", isFinal: true)))
        #expect(events.contains(.speechEnded))

        runner.terminate()
    }

    @Test func sendShutdownTerminatesProcess() async throws {
        let runner = ProcessRunner()
        try runner.start(
            executableURL: pythonURL(),
            arguments: pythonArguments()
        )

        // Wait for ready
        for await event in runner.events {
            if event == .ready { break }
        }

        // Send shutdown
        try runner.send(.shutdown)

        // Drain remaining events — stream should finish
        for await _ in runner.events {}

        // Process should have exited
        // Give it a moment to clean up
        try await Task.sleep(for: .milliseconds(100))
        #expect(!runner.isRunning)
    }

    @Test func receiveStderrLogs() async throws {
        let runner = ProcessRunner()
        try runner.start(
            executableURL: pythonURL(),
            arguments: pythonArguments()
        )

        // Should receive log from mock server
        var receivedLog = false
        for await log in runner.logs {
            if log.contains("Mock server ready") {
                receivedLog = true
                break
            }
        }
        #expect(receivedLog)
        runner.terminate()
    }

    @Test func startWhileRunningThrows() async throws {
        let runner = ProcessRunner()
        try runner.start(
            executableURL: pythonURL(),
            arguments: pythonArguments()
        )

        #expect(throws: ProcessRunner.Error.self) {
            try runner.start(
                executableURL: pythonURL(),
                arguments: pythonArguments()
            )
        }

        runner.terminate()
    }

    @Test func sendWhileNotRunningThrows() async throws {
        let runner = ProcessRunner()
        #expect(throws: ProcessRunner.Error.self) {
            try runner.send(.start)
        }
    }
}
