import XCTest
import os
import LessonKit
@testable import GramartEnglish

/// F010 v1.11.0 patch — Priya's blocker. The pre-patch resume path on
/// launch used `LessonMode(rawValue: snap.mode) ?? .readPickMeaning`,
/// which silently routed a snapshot with an unknown mode rawValue
/// (corrupt file, future-schema regression, stale build) into
/// `readPickMeaning` with the wrong mastery accounting and no signal
/// anything was broken.
///
/// These tests pin the new contract on the extracted helper
/// `ReadyFlowView.recoverResumePhase(...)`:
///   - unknown mode → snapshot is cleared, helper returns nil
///   - known mode + matching resumable lessonId → returns `.lesson(...)`
///   - mismatched lessonId (stale snapshot) → snapshot is cleared
///   - nil snapshot → helper short-circuits without touching the store
final class RootViewResumeRecoveryTests: XCTestCase {

    private var tempDir: URL!
    private let logger = Logger(subsystem: "com.gramart.english.tests", category: "ResumeRecoveryTests")

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RootViewResumeRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private func makeStore() -> LessonStateStore {
        let store = LessonStateStore(directory: tempDir)
        store.debounceOverrideMillis = 0
        return store
    }

    private func snapshot(mode: String, lessonId: String = "lesson-1") -> LessonStateSnapshot {
        LessonStateSnapshot(
            lessonId: lessonId,
            mode: mode,
            level: "A2",
            phase: .answering,
            currentQuestionIndex: 2,
            answeredCount: 2
        )
    }

    func test_unknownMode_returnsNil_andClearsStore() {
        let store = makeStore()
        let snap = snapshot(mode: "invalid_mode_xyz")
        store.save(snap); store.flush()
        XCTAssertNotNil(store.load(), "precondition: snapshot is on disk")

        let result = ReadyFlowView.recoverResumePhase(
            snapshot: snap,
            resumableLessonId: snap.lessonId, // server agrees the lesson is resumable
            store: store,
            logger: logger
        )

        XCTAssertNil(result, "Unknown mode must NOT silently coerce to readPickMeaning")
        XCTAssertNil(store.load(), "Store must be cleared so the next launch lands on Home")
    }

    func test_unknownMode_doesNotCrash_evenWithNoMatchingResumable() {
        // Defense-in-depth: even if the server doesn't claim a resumable
        // lesson, an unknown-mode snapshot should still be discarded.
        let store = makeStore()
        let snap = snapshot(mode: "future_mode_added_in_v2")
        store.save(snap); store.flush()

        let result = ReadyFlowView.recoverResumePhase(
            snapshot: snap,
            resumableLessonId: nil,
            store: store,
            logger: logger
        )

        XCTAssertNil(result)
        XCTAssertNil(store.load())
    }

    func test_validMode_andMatchingLessonId_returnsLessonPhase() {
        let store = makeStore()
        let snap = snapshot(mode: LessonMode.listenPickWord.rawValue, lessonId: "lesson-42")
        store.save(snap); store.flush()

        let result = ReadyFlowView.recoverResumePhase(
            snapshot: snap,
            resumableLessonId: "lesson-42",
            store: store,
            logger: logger
        )

        switch result {
        case .lesson(let level, let mode, let resumeId):
            XCTAssertEqual(level, "A2")
            XCTAssertEqual(mode, .listenPickWord)
            XCTAssertEqual(resumeId, "lesson-42")
        default:
            XCTFail("Expected .lesson phase, got \(String(describing: result))")
        }
        XCTAssertNotNil(store.load(), "Valid resume must NOT clear the store — the lesson flow still needs it")
    }

    func test_staleSnapshot_serverHasDifferentLesson_clearsAndReturnsNil() {
        let store = makeStore()
        let snap = snapshot(mode: LessonMode.readPickMeaning.rawValue, lessonId: "lesson-old")
        store.save(snap); store.flush()

        let result = ReadyFlowView.recoverResumePhase(
            snapshot: snap,
            resumableLessonId: "lesson-new",
            store: store,
            logger: logger
        )

        XCTAssertNil(result)
        XCTAssertNil(store.load(), "Stale snapshot must be cleared")
    }

    func test_nilSnapshot_returnsNil_withoutTouchingStore() {
        let store = makeStore()
        // Pre-plant something so we can detect spurious clears.
        let unrelated = snapshot(mode: LessonMode.readPickMeaning.rawValue)
        store.save(unrelated); store.flush()

        let result = ReadyFlowView.recoverResumePhase(
            snapshot: nil,
            resumableLessonId: nil,
            store: store,
            logger: logger
        )

        XCTAssertNil(result)
        XCTAssertNotNil(store.load(), "nil snapshot input must not clear an unrelated on-disk snapshot")
    }
}
