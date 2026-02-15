/// Async wrapper around Foundation.Process + Pipe for communicating with
/// the Python STT server via stdin/stdout JSON lines protocol.

import Foundation
import os

/// Manages a child process, providing typed command sending and event receiving.
final class ProcessRunner: Sendable {
    /// Errors specific to ProcessRunner operations.
    enum Error: Swift.Error, Sendable {
        case notRunning
        case alreadyRunning
        case processExited(terminationStatus: Int32)
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.speak-pilot",
        category: "ProcessRunner"
    )

    // Nonisolated state protected by lock
    private let lock = NSLock()
    private nonisolated(unsafe) var _process: Process?
    private nonisolated(unsafe) var _stdinHandle: FileHandle?
    private nonisolated(unsafe) var _eventContinuation: AsyncStream<BackendEvent>.Continuation?
    private nonisolated(unsafe) var _logContinuation: AsyncStream<String>.Continuation?
    private nonisolated(unsafe) var _eventStream: AsyncStream<BackendEvent>?
    private nonisolated(unsafe) var _logStream: AsyncStream<String>?

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    private let decoder = JSONDecoder()

    init() {}

    /// Whether the managed process is currently running.
    var isRunning: Bool {
        lock.withLock { _process?.isRunning ?? false }
    }

    /// Stream of decoded events from the process stdout.
    /// Only valid after `start()` has been called.
    var events: AsyncStream<BackendEvent> {
        lock.withLock { _eventStream ?? AsyncStream { $0.finish() } }
    }

    /// Stream of log lines from the process stderr.
    /// Only valid after `start()` has been called.
    var logs: AsyncStream<String> {
        lock.withLock { _logStream ?? AsyncStream { $0.finish() } }
    }

    /// Start the child process.
    ///
    /// - Parameters:
    ///   - executableURL: URL to the executable (e.g. path to `uv` or `python`).
    ///   - arguments: Command-line arguments.
    ///   - environment: Optional environment variables. If nil, inherits current.
    ///   - currentDirectoryURL: Optional working directory for the process.
    func start(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) throws {
        try lock.withLock {
            guard _process == nil else {
                throw Error.alreadyRunning
            }

            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            if let environment {
                process.environment = environment
            }
            if let currentDirectoryURL {
                process.currentDirectoryURL = currentDirectoryURL
            }

            // Set up pipes
            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Create async streams
            let (eventStream, eventContinuation) = AsyncStream<BackendEvent>.makeStream()
            let (logStream, logContinuation) = AsyncStream<String>.makeStream()

            _eventStream = eventStream
            _logStream = logStream
            _eventContinuation = eventContinuation
            _logContinuation = logContinuation
            _stdinHandle = stdinPipe.fileHandleForWriting
            _process = process

            // Read stdout lines → decode BackendEvent
            stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    // EOF
                    self?.lock.withLock { self?._eventContinuation?.finish() }
                    return
                }
                self?.handleStdoutData(data)
            }

            // Read stderr lines → forward as log strings
            stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    self?.lock.withLock { self?._logContinuation?.finish() }
                    return
                }
                if let text = String(data: data, encoding: .utf8) {
                    // Split into lines and yield each
                    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                    self?.lock.withLock {
                        for line in lines where !line.isEmpty {
                            self?._logContinuation?.yield(String(line))
                        }
                    }
                }
            }

            // Handle process termination
            process.terminationHandler = { [weak self] proc in
                guard let self else { return }
                let status = proc.terminationStatus
                self.lock.lock()
                if status != 0 {
                    self.logger.warning("Process exited with status \(status)")
                    self._eventContinuation?.yield(
                        .error(message: "Process exited with status \(status)")
                    )
                }
                self._eventContinuation?.finish()
                self._logContinuation?.finish()
                self._process = nil
                self._stdinHandle = nil
                self.lock.unlock()
            }

            try process.run()
            logger.info("Process started: \(executableURL.path())")
        }
    }

    /// Send a command to the process via stdin.
    func send(_ command: BackendCommand) throws {
        let (handle, isRunning) = lock.withLock {
            (_stdinHandle, _process?.isRunning ?? false)
        }
        guard isRunning, let handle else {
            throw Error.notRunning
        }
        var data = try encoder.encode(command)
        data.append(contentsOf: [UInt8(ascii: "\n")])
        try handle.write(contentsOf: data)
    }

    /// Terminate the process gracefully, then force-kill if needed.
    func terminate() {
        lock.withLock {
            guard let process = _process, process.isRunning else { return }
            process.terminate()
        }
    }

    // MARK: - Private

    /// Buffer for partial stdout lines (JSON lines may arrive split across reads).
    private nonisolated(unsafe) var stdoutBuffer = Data()

    private func handleStdoutData(_ data: Data) {
        lock.withLock {
            stdoutBuffer.append(data)

            // Process complete lines
            while let newlineIndex = stdoutBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = stdoutBuffer[stdoutBuffer.startIndex..<newlineIndex]
                stdoutBuffer = Data(stdoutBuffer[stdoutBuffer.index(after: newlineIndex)...])

                guard !lineData.isEmpty else { continue }

                do {
                    let event = try decoder.decode(BackendEvent.self, from: Data(lineData))
                    _eventContinuation?.yield(event)
                } catch {
                    logger.warning("Failed to decode event: \(error)")
                }
            }
        }
    }
}
