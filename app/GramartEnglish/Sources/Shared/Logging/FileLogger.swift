import Foundation
import os

/// Rotating file logger writing JSON-line records under
/// `~/Library/Logs/GramartEnglish/app-*.log`. Files rotate at 10 MB; keeps the
/// last 5.
public final class FileLogger {

    public static let shared = FileLogger()

    private let queue = DispatchQueue(label: "com.gramart.english.filelogger", qos: .utility)
    private let osLog = Logger(subsystem: "com.gramart.english", category: "FileLogger")
    private let directory: URL
    private let baseName: String
    private let maxBytes: Int
    private let maxFiles: Int

    public init(
        directory: URL? = nil,
        baseName: String = "app",
        maxBytes: Int = 10 * 1024 * 1024,
        maxFiles: Int = 5
    ) {
        if let directory {
            self.directory = directory
        } else {
            let logs = FileManager.default
                .urls(for: .libraryDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent("GramartEnglish", isDirectory: true)
            self.directory = logs
        }
        self.baseName = baseName
        self.maxBytes = maxBytes
        self.maxFiles = maxFiles
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    public func log(_ level: String, _ event: String, correlationId: String? = nil, fields: [String: String] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var record: [String: String] = [
            "ts": timestamp,
            "level": level,
            "event": event,
        ]
        if let correlationId { record["correlationId"] = correlationId }
        for (k, v) in fields { record[k] = v }

        queue.async { [weak self] in
            guard let self else { return }
            let path = self.currentLogPath()
            let data = (Self.encodeLine(record)).data(using: .utf8) ?? Data()
            self.appendAndRotate(data: data, at: path)
        }
    }

    private static func encodeLine(_ record: [String: String]) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])).flatMap {
            String(data: $0, encoding: .utf8)
        } ?? "{}"
        return json + "\n"
    }

    private func currentLogPath() -> URL {
        directory.appendingPathComponent("\(baseName).log")
    }

    private func appendAndRotate(data: Data, at path: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path.path) {
            fm.createFile(atPath: path.path, contents: data)
            return
        }
        do {
            let handle = try FileHandle(forWritingTo: path)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            let size = try handle.offset()
            if size >= UInt64(maxBytes) {
                rotate()
            }
        } catch {
            osLog.error("FileLogger write failed: \(error.localizedDescription)")
        }
    }

    private func rotate() {
        let fm = FileManager.default
        for i in stride(from: maxFiles - 1, to: 0, by: -1) {
            let src = directory.appendingPathComponent("\(baseName).\(i).log")
            let dst = directory.appendingPathComponent("\(baseName).\(i + 1).log")
            if fm.fileExists(atPath: src.path) {
                try? fm.removeItem(at: dst)
                try? fm.moveItem(at: src, to: dst)
            }
        }
        let current = directory.appendingPathComponent("\(baseName).log")
        let archived = directory.appendingPathComponent("\(baseName).1.log")
        try? fm.removeItem(at: archived)
        try? fm.moveItem(at: current, to: archived)
    }
}
