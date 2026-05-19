import Foundation
import os

/// Manages the lifecycle of the embedded Node.js backend process.
///
/// Responsibilities:
///   - Launch the bundled `node` binary on `127.0.0.1:0`.
///   - Read the single-line JSON handshake on stdout `{port, pid, version}`.
///   - Auto-relaunch on unexpected exit up to `maxRelaunches` times.
///   - Terminate cleanly on app shutdown.
public actor BackendSupervisor {

    public struct Handshake: Codable, Sendable, Equatable {
        public let port: Int
        public let pid: Int
        public let version: String
    }

    public enum SupervisorError: Error, Sendable {
        case handshakeMalformed(String)
        case binaryMissing(String)
        case relaunchLimitExceeded
        case processFailed(Int32)
    }

    public struct LaunchOptions: Sendable {
        public var nodeBinary: URL
        public var scriptPath: URL
        public var workingDirectory: URL
        public var environment: [String: String]
        public var maxRelaunches: Int

        public init(
            nodeBinary: URL,
            scriptPath: URL,
            workingDirectory: URL,
            environment: [String: String] = [:],
            maxRelaunches: Int = 2
        ) {
            self.nodeBinary = nodeBinary
            self.scriptPath = scriptPath
            self.workingDirectory = workingDirectory
            self.environment = environment
            self.maxRelaunches = maxRelaunches
        }
    }

    private let log = Logger(subsystem: "com.gramart.english", category: "BackendSupervisor")
    private var process: Process?
    private var relaunchCount = 0
    private var currentHandshake: Handshake?

    public init() {}

    /// Parses a single handshake line. Public for unit testing.
    public static func parseHandshake(_ line: String) throws -> Handshake {
        guard let data = line.data(using: .utf8) else {
            throw SupervisorError.handshakeMalformed("non-utf8 line")
        }
        do {
            return try JSONDecoder().decode(Handshake.self, from: data)
        } catch {
            throw SupervisorError.handshakeMalformed("decode failed: \(error)")
        }
    }

    public func start(_ options: LaunchOptions) async throws -> Handshake {
        guard FileManager.default.isExecutableFile(atPath: options.nodeBinary.path) else {
            throw SupervisorError.binaryMissing(options.nodeBinary.path)
        }
        return try await spawnOnce(options)
    }

    public func currentPort() -> Int? {
        currentHandshake?.port
    }

    public func stop() async {
        guard let process else { return }
        if process.isRunning {
            process.terminate()
        }
        self.process = nil
        self.currentHandshake = nil
    }

    private func spawnOnce(_ options: LaunchOptions) async throws -> Handshake {
        let process = Process()
        process.executableURL = options.nodeBinary
        process.arguments = [options.scriptPath.path]
        process.currentDirectoryURL = options.workingDirectory
        process.environment = ProcessInfo.processInfo.environment.merging(options.environment) { _, new in new }
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        self.process = process

        let handshake = try await readHandshake(from: stdout)
        self.currentHandshake = handshake
        log.info("backend ready on port \(handshake.port) pid \(handshake.pid) version \(handshake.version)")
        return handshake
    }

    private func readHandshake(from pipe: Pipe) async throws -> Handshake {
        // Stream stdout and try parsing each newline-terminated line as a
        // Handshake. Skip lines that aren't (they're pino log entries the
        // bundled backend emits during boot — `corpus.loaded`,
        // `rag.index.not_built`, etc. — and arrive BEFORE the handshake).
        //
        // `availableData` is non-blocking unless the pipe is closed; we poll
        // on a 50ms cadence so the deadline check actually fires.
        let handle = pipe.fileHandleForReading
        var buffer = Data()
        let timeout: TimeInterval = 10
        let deadline = Date().addingTimeInterval(timeout)
        var skippedLines = 0
        while Date() < deadline {
            let chunk = handle.availableData
            if chunk.isEmpty {
                try await Task.sleep(nanoseconds: 50_000_000)
                continue
            }
            buffer.append(chunk)
            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.prefix(upTo: newlineIndex)
                buffer.removeSubrange(0...newlineIndex)
                guard let line = String(data: lineData, encoding: .utf8) else {
                    skippedLines += 1
                    continue
                }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                // Heuristic: only attempt parse on lines that look like the
                // handshake shape `{"port":...}`. Saves wasteful decode work
                // on the dozen pino log lines that go through this pipe.
                if !trimmed.hasPrefix("{\"port\"") {
                    skippedLines += 1
                    continue
                }
                do {
                    return try Self.parseHandshake(trimmed)
                } catch {
                    skippedLines += 1
                    if skippedLines > 32 {
                        throw SupervisorError.handshakeMalformed("no handshake after \(skippedLines) lines")
                    }
                }
            }
        }
        throw SupervisorError.handshakeMalformed("timeout after \(timeout)s, skipped \(skippedLines) lines")
    }
}
