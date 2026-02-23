/// Manages the Python STT backend process lifecycle.
///
/// Wraps `ProcessRunner` to provide high-level start/stop/shutdown operations
/// with observable state for UI binding.

import Foundation
import os

@MainActor
@Observable
final class BackendManager {
    /// Current state of the backend.
    enum State: Sendable, Equatable {
        case idle
        case starting
        case ready
        case listening
        case error(String)
    }

    // MARK: - Observable properties

    private(set) var state: State = .idle

    /// The latest transcription text (partial or final).
    private(set) var currentTranscription: String = ""

    // MARK: - Callback

    /// Called on the main actor when a partial transcription is received.
    var onPartialTranscription: (@MainActor @Sendable (String) -> Void)?

    /// Called on the main actor when a final transcription is received.
    var onFinalTranscription: (@MainActor @Sendable (String) -> Void)?

    // MARK: - Internal

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.speak-pilot",
        category: "BackendManager"
    )

    private var processRunner: ProcessRunner?
    private var eventTask: Task<Void, Never>?
    private var logTask: Task<Void, Never>?

    private let commandResolver: BackendCommandResolver

    init(commandResolver: BackendCommandResolver = DefaultBackendCommandResolver()) {
        self.commandResolver = commandResolver
    }

    // MARK: - Public API

    /// Launch the Python backend process and wait until it becomes ready.
    func launch() async throws {
        guard state == .idle || isErrorState else {
            logger.warning("launch() called in state \(String(describing: self.state))")
            return
        }

        state = .starting
        currentTranscription = ""

        let runner: ProcessRunner
        do {
            let command = try commandResolver.resolve()
            logger.info(
                "Launching backend: \(command.executableURL.path(), privacy: .public) \(command.arguments.joined(separator: " "), privacy: .public)"
            )
            runner = ProcessRunner()
            try runner.start(
                executableURL: command.executableURL,
                arguments: command.arguments,
                environment: command.environment,
                currentDirectoryURL: command.currentDirectoryURL
            )
        } catch {
            logger.error("Failed to launch backend: \(error, privacy: .public)")
            state = .error(error.localizedDescription)
            throw error
        }

        processRunner = runner
        startLogForwarding(runner)
        try await waitForReady(runner)
    }

    /// Send `start` command to begin listening.
    func startListening() throws {
        guard state == .ready else {
            logger.warning("startListening() called in state \(String(describing: self.state))")
            return
        }
        try processRunner?.send(.start)
        state = .listening
    }

    /// Send `stop` command to stop listening.
    func stopListening() throws {
        guard state == .listening else {
            logger.warning("stopListening() called in state \(String(describing: self.state))")
            return
        }
        try processRunner?.send(.stop)
        state = .ready
        currentTranscription = ""
    }

    /// Gracefully shut down the backend process.
    func shutdown() async {
        guard processRunner != nil else { return }

        do {
            try processRunner?.send(.shutdown)
        } catch {
            logger.warning("Failed to send shutdown command: \(error)")
        }

        eventTask?.cancel()
        logTask?.cancel()

        // Give the process a moment to exit gracefully
        try? await Task.sleep(for: .milliseconds(500))

        if processRunner?.isRunning == true {
            processRunner?.terminate()
        }

        cleanup()
        state = .idle
        currentTranscription = ""
    }

    // MARK: - Private

    private var isErrorState: Bool {
        if case .error = state { return true }
        return false
    }

    /// Wait for the `ready` event from the backend, forwarding events along the way.
    private func waitForReady(_ runner: ProcessRunner) async throws {
        // Start event processing loop
        eventTask = Task { @MainActor [weak self] in
            for await event in runner.events {
                guard let self, !Task.isCancelled else { return }
                self.handleEvent(event)
            }
            // Stream ended — process has exited
            guard let self, !Task.isCancelled else { return }
            self.handleProcessExit()
        }

        // Wait until state transitions from .starting
        let deadline = ContinuousClock.now + .seconds(30)
        while state == .starting {
            if ContinuousClock.now > deadline {
                eventTask?.cancel()
                logTask?.cancel()
                processRunner?.terminate()
                cleanup()
                throw BackendManagerError.startupTimeout
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        // If we ended up in an error state during startup, throw
        if case .error(let message) = state {
            throw BackendManagerError.startupFailed(message)
        }
    }

    private func handleEvent(_ event: BackendEvent) {
        switch event {
        case .ready:
            if state == .starting {
                state = .ready
                logger.info("Backend is ready")
            }
        case .speechStarted:
            logger.debug("Speech started")
        case .transcription(let text, let isFinal):
            currentTranscription = text
            if isFinal {
                logger.info("Final transcription: \(text)")
                onFinalTranscription?(text)
            } else {
                onPartialTranscription?(text)
            }
        case .speechEnded:
            logger.debug("Speech ended")
        case .error(let message):
            logger.error("Backend error: \(message)")
            state = .error(message)
        }
    }

    private func handleProcessExit() {
        let wasExpected = (state == .idle)
        if !wasExpected {
            logger.warning(
                "Backend process exited unexpectedly in state \(String(describing: self.state), privacy: .public)")
            if !isErrorState {
                state = .error("Backend process exited unexpectedly")
            }
        }
        cleanup()
    }

    private func startLogForwarding(_ runner: ProcessRunner) {
        logTask = Task { [weak self] in
            for await line in runner.logs {
                guard !Task.isCancelled else { return }
                self?.logger.info("[\u{200B}backend] \(line, privacy: .public)")
            }
        }
    }

    private func cleanup() {
        processRunner = nil
        eventTask = nil
        logTask = nil
    }
}

// MARK: - Errors

enum BackendManagerError: Error, LocalizedError, Sendable {
    case startupTimeout
    case startupFailed(String)

    var errorDescription: String? {
        switch self {
        case .startupTimeout:
            "バックエンドの起動がタイムアウトしました（30秒）。Console.app で SpeakPilot のログを確認してください。"
        case .startupFailed(let message):
            "バックエンドの起動に失敗しました: \(message)"
        }
    }
}

// MARK: - Command resolver (protocol for testability)

/// Resolved command to launch the backend process.
struct BackendCommand_Launch: Sendable {
    let executableURL: URL
    let arguments: [String]
    let environment: [String: String]?
    let currentDirectoryURL: URL?
}

/// Resolves the executable and arguments for launching the Python backend.
protocol BackendCommandResolver: Sendable {
    func resolve() throws -> BackendCommand_Launch
}

/// Default resolver that uses `uv run` to launch the Python STT server.
struct DefaultBackendCommandResolver: BackendCommandResolver {
    func resolve() throws -> BackendCommand_Launch {
        let uvURL = try findExecutable(named: "uv")
        let projectDir = try resolveProjectDirectory()
        let arguments = [
            "run",
            "--project", projectDir.path(),
            "python", "-m", "speak_pilot_stt_stdio",
        ]
        // Remove UV_PROJECT_ENVIRONMENT so that `uv run --project` creates its own
        // virtual environment instead of reusing an external one (e.g. devenv's venv)
        // where the stt-stdio-server package is not installed.
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "UV_PROJECT_ENVIRONMENT")
        return BackendCommand_Launch(
            executableURL: uvURL,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: projectDir
        )
    }

    /// Resolve the `stt-stdio-server/` directory to an absolute path.
    ///
    /// Search order:
    /// 1. Sibling of the executable (for development via `swift run`)
    /// 2. Walk up from the executable to find the project root containing `stt-stdio-server/`
    private func resolveProjectDirectory() throws -> URL {
        let fm = FileManager.default

        // Start from the directory containing the executable binary.
        let executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        var searchDir = executableURL.deletingLastPathComponent()

        // Walk up the directory tree looking for stt-stdio-server/
        for _ in 0..<10 {
            let candidate = searchDir.appending(path: "stt-stdio-server")
            if fm.isDirectory(at: candidate) {
                return candidate
            }
            let parent = searchDir.deletingLastPathComponent()
            if parent.path() == searchDir.path() { break }
            searchDir = parent
        }

        throw BackendResolverError.projectDirectoryNotFound
    }

    private func findExecutable(named name: String) throws -> URL {
        let commonPaths = [
            "/usr/local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // Try `which` as a fallback
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines),
                !path.isEmpty
            {
                return URL(fileURLWithPath: path)
            }
        }

        throw ExecutableNotFoundError(name: name)
    }
}

// MARK: - FileManager helper

extension FileManager {
    /// Check if a URL points to a directory.
    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: url.path(), isDirectory: &isDir) && isDir.boolValue
    }
}

// MARK: - Resolver errors

enum BackendResolverError: Error, LocalizedError, Sendable {
    case projectDirectoryNotFound

    var errorDescription: String? {
        switch self {
        case .projectDirectoryNotFound:
            "stt-stdio-server/ ディレクトリが見つかりません。プロジェクトルートから実行してください。"
        }
    }
}

struct ExecutableNotFoundError: Error, LocalizedError, Sendable {
    let name: String

    var errorDescription: String? {
        "実行ファイル '\(name)' が見つかりません。PATH を確認してください。"
    }
}
