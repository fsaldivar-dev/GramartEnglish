import Foundation

/// F007 (v1.8.0) — Persisted snapshot of an in-flight lesson so a hard quit
/// (Cmd+Q, crash, force-kill) doesn't destroy ~15 min of learner progress.
///
/// Why a separate store from `VerbIntroSeenStore`:
/// - This payload is non-trivial (lessonId + mode + level + index + outcomes
///   count); UserDefaults would still work but a JSON file under
///   `Application Support` is the macOS-idiomatic home for structured app
///   state and is easier to inspect when triaging Marisol's reports.
/// - It needs atomic writes (avoid partial JSON on a crash mid-write).
/// - It needs debouncing (a burst of phase transitions during reveal/next
///   would otherwise hammer the disk).
///
/// Concurrency: `save` may be called from any actor — internally we hop to
/// our own serial queue for both the debounce timer and the atomic-write
/// step. `load` is synchronous and intended for the launch path (RootView
/// `.task`), where it runs once.
///
/// Failure modes:
/// - Missing file → `load()` returns nil (the steady state on first launch).
/// - Corrupt JSON → `load()` deletes the file and returns nil (don't crash
///   the app for the user; better to start fresh than to brick startup).
/// - Disk full / permission error during save → we log to stderr and drop
///   the write. The next successful save catches us up. The learner only
///   loses the savepoint, not the current run.
public struct LessonStateSnapshot: Codable, Equatable, Sendable {

    public enum Phase: String, Codable, Sendable {
        /// Question is being answered (no reveal yet).
        case answering
        /// Outcome revealed; user has not advanced.
        case revealing
    }

    public let lessonId: String
    /// LessonMode raw value (e.g. `"read_pick_meaning"`). String instead of
    /// the enum so a future mode added by the backend doesn't fail to decode
    /// an old snapshot — caller treats unknown modes as "discard and start
    /// fresh".
    public let mode: String
    public let level: String
    public let phase: Phase
    /// Zero-based index of the question the learner is currently on. On
    /// resume the client asks the server for the lesson by id; this index
    /// is a hint for which question to display first if the server returns
    /// the full lesson.
    public let currentQuestionIndex: Int
    /// Number of outcomes already recorded server-side. Echoed back so the
    /// client can sanity-check that the server-resumable state lines up with
    /// what we saved locally; mismatches → snapshot wins on count, server on
    /// content (we don't replay outcomes locally).
    public let answeredCount: Int
    /// ISO 8601 timestamp of when this snapshot was written. Useful for
    /// "you started this 2h ago — keep going?" prompts in a future iteration
    /// and for debugging stale-snapshot reports.
    public let savedAt: Date

    public init(
        lessonId: String,
        mode: String,
        level: String,
        phase: Phase,
        currentQuestionIndex: Int,
        answeredCount: Int,
        savedAt: Date = .now
    ) {
        self.lessonId = lessonId
        self.mode = mode
        self.level = level
        self.phase = phase
        self.currentQuestionIndex = currentQuestionIndex
        self.answeredCount = answeredCount
        self.savedAt = savedAt
    }
}

public final class LessonStateStore: @unchecked Sendable {

    public static let shared = LessonStateStore()

    /// Minimum interval between disk writes for the same store instance.
    /// 500ms keeps us under one write per phase transition in normal flow
    /// (answer → reveal → next ≈ ~1.5s) while still flushing fast enough
    /// that a Cmd+Q within a couple of seconds of the last user gesture
    /// keeps the freshest state.
    public static let debounceMillis: Int = 500

    private let fileURL: URL
    private let queue = DispatchQueue(label: "gramart.lessonStateStore", qos: .utility)
    private var pendingSnapshot: LessonStateSnapshot?
    private var writeScheduled = false
    /// Test affordance — when set, `flushDebounced` runs synchronously rather
    /// than after `debounceMillis`. Production code never touches this.
    var debounceOverrideMillis: Int?

    /// Production path: writes under `~/Library/Application Support/GramartEnglish/`.
    /// Tests pass a temp directory.
    public init(directory: URL? = nil) {
        let dir: URL
        if let directory {
            dir = directory
        } else {
            let support = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? FileManager.default.temporaryDirectory
            dir = support.appendingPathComponent("GramartEnglish", isDirectory: true)
        }
        // Best-effort directory creation; subsequent writes will surface any
        // permission issue.
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("lesson-state.json")
    }

    /// Read the persisted snapshot if any. Returns nil for no-file and for
    /// corrupt-file (and in the corrupt case, deletes the file so the next
    /// launch doesn't hit the same parse error).
    public func load() -> LessonStateSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(LessonStateSnapshot.self, from: data)
        } catch {
            // Corrupt or stale schema — drop it and start fresh.
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }

    /// Enqueue a snapshot. Debounced: rapid-fire saves collapse into one
    /// disk write per `debounceMillis` window.
    public func save(_ snapshot: LessonStateSnapshot) {
        queue.async { [weak self] in
            guard let self else { return }
            self.pendingSnapshot = snapshot
            if self.writeScheduled { return }
            self.writeScheduled = true
            let delay = self.debounceOverrideMillis ?? Self.debounceMillis
            self.queue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
                self?.flushPending()
            }
        }
    }

    /// Force the pending snapshot to disk now. Call sites: tests, and the
    /// `complete` path (we want the clear to land before the process is
    /// torn down).
    public func flush() {
        queue.sync { self.flushPending() }
    }

    /// Delete the snapshot. Called when a lesson completes successfully or
    /// when the user explicitly abandons it — there's nothing left to
    /// resume.
    public func clear() {
        queue.sync {
            self.pendingSnapshot = nil
            self.writeScheduled = false
            try? FileManager.default.removeItem(at: self.fileURL)
        }
    }

    // MARK: - Private

    /// Runs on `queue`. Writes the most recent pending snapshot atomically
    /// (write to a `.tmp` then rename); a crash mid-write leaves the old
    /// file intact rather than producing a half-encoded JSON blob the next
    /// launch can't parse.
    private func flushPending() {
        defer { writeScheduled = false }
        guard let snapshot = pendingSnapshot else { return }
        pendingSnapshot = nil
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys] // deterministic for diffing
            let data = try encoder.encode(snapshot)
            let tmpURL = fileURL.appendingPathExtension("tmp")
            try data.write(to: tmpURL, options: .atomic)
            // `replaceItem` keeps the destination's permissions and is
            // atomic on APFS.
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
        } catch {
            // Drop the write. The next successful save will catch up.
            FileHandle.standardError.write(Data(
                "[LessonStateStore] save failed: \(error.localizedDescription)\n".utf8
            ))
        }
    }
}
