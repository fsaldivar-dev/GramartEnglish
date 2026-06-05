import XCTest
import BackendClient
import LessonKit
@testable import GramartEnglish

/// F011 Item 4 (v1.12.0). QA blocker from the v1.11 round: Priya's
/// Polish A plumbed `totalCount` through the CONSUMER side
/// (`ResumeLessonCard` renders "Pregunta X de Y") but a small window
/// existed where the SNAPSHOT GENERATOR could emit `totalCount = nil`
/// — namely, any new persistence call-site added later that bypassed
/// the central `snapshot(for:)` builder.
///
/// This file pins the invariant: every snapshot produced by the
/// `LessonViewModel` during an in-flight lesson carries a non-nil
/// `totalCount` equal to the lesson's `questions.count`. The audit was
/// clean (every save routes through `persistSnapshot()` →
/// `snapshot(for:)`), so these tests act as a regression net for the
/// next change.
///
/// Scenarios covered:
///   1. After `start()` (first persistence — the launch path)
///   2. After `answer()` → `.revealing` (the most common transition)
///   3. After `dismissVerbIntro()` (v1.7 conjugate gate, persists on
///      dismiss so a Cmd+Q between intro-dismissed and first-answer
///      doesn't re-show the card)
///   4. After `skip()` (the FR-009 path)
///   5. After abandon mid-lesson (`onExit` does NOT clear the snapshot;
///      the last persisted save must retain `totalCount`)
@MainActor
final class SnapshotTotalCountTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    private func freshStore() -> LessonStateStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapshotTotalCountTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = LessonStateStore(directory: dir)
        store.debounceOverrideMillis = 0
        return store
    }

    private func makeViewModel(store: LessonStateStore, mode: LessonMode = .readPickMeaning) -> LessonViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = BackendClient(baseURL: URL(string: "http://127.0.0.1:1234")!, session: session) {
            "deadbeef-dead-4dad-8dad-deadbeefdead"
        }
        return LessonViewModel(client: client, level: "A1", mode: mode, stateStore: store)
    }

    /// 3-question lesson — keeps the total non-trivial so a stub
    /// hardcoded to 2 in the persistence path would be caught.
    private nonisolated static func startBody() -> Data {
        """
        {
          "lessonId": "11111111-1111-4111-8111-111111111111",
          "questions": [
            {"id":"22222222-2222-4222-8222-222222222221","word":"house","options":["A","B","C","D"],"position":0},
            {"id":"22222222-2222-4222-8222-222222222222","word":"eat","options":["A","B","C","D"],"position":1},
            {"id":"22222222-2222-4222-8222-222222222223","word":"run","options":["A","B","C","D"],"position":2}
          ]
        }
        """.data(using: .utf8)!
    }

    private nonisolated static func answerBody() -> Data {
        """
        {"outcome":"correct","correctIndex":1,"correctOption":"B","canonicalDefinition":"def"}
        """.data(using: .utf8)!
    }

    private nonisolated static func skipBody() -> Data {
        """
        {"outcome":"skipped","correctIndex":2,"correctOption":"C","canonicalDefinition":"def"}
        """.data(using: .utf8)!
    }

    // MARK: - 1. After start()

    func testSnapshotAfterStartCarriesTotalCount() async {
        let store = freshStore()
        let vm = makeViewModel(store: store)
        TestURLProtocol.handler = { _ in (200, Self.startBody()) }
        await vm.start()
        store.flush()
        let snap = store.load()
        XCTAssertNotNil(snap?.totalCount, "Snapshot after start() must carry totalCount (QA blocker)")
        XCTAssertEqual(snap?.totalCount, 3)
    }

    // MARK: - 2. After answer() → revealing

    func testSnapshotAfterAnswerCarriesTotalCount() async {
        let store = freshStore()
        let vm = makeViewModel(store: store)
        TestURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/lessons") ?? false { return (200, Self.startBody()) }
            return (200, Self.answerBody())
        }
        await vm.start()
        await vm.answer(1)
        store.flush()
        let snap = store.load()
        XCTAssertEqual(snap?.phase, .revealing)
        XCTAssertEqual(snap?.totalCount, 3)
    }

    // MARK: - 3. After dismissVerbIntro()
    //
    // The conjugate-pick-form mode triggers VerbIntroCard on the first
    // question per verb. `dismissVerbIntro()` re-persists so a Cmd+Q
    // mid-dismiss doesn't lose the position. We don't need the intro
    // payload to actually surface to test this — we just need the
    // persistence path to fire from a `.answering` phase. The lesson
    // body has no `verbBase` so `presentIntroIfNeeded` no-ops, and we
    // call `dismissVerbIntro()` directly to exercise the save.

    func testSnapshotAfterDismissVerbIntroCarriesTotalCount() async {
        let store = freshStore()
        let vm = makeViewModel(store: store, mode: .conjugatePickForm)
        TestURLProtocol.handler = { _ in (200, Self.startBody()) }
        await vm.start()
        // dismissVerbIntro is safe to call even when pendingIntro is
        // nil — it short-circuits the markSeen step and still calls
        // persistSnapshot(), which is the path we want pinned.
        vm.dismissVerbIntro()
        store.flush()
        let snap = store.load()
        XCTAssertEqual(snap?.totalCount, 3,
            "dismissVerbIntro persistence must keep totalCount intact")
    }

    // MARK: - 4. After skip()

    func testSnapshotAfterSkipCarriesTotalCount() async {
        let store = freshStore()
        let vm = makeViewModel(store: store)
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.startBody()) }
            if path.contains("/skip")     { return (200, Self.skipBody()) }
            return (404, Data())
        }
        await vm.start()
        await vm.skip()
        store.flush()
        let snap = store.load()
        XCTAssertEqual(snap?.phase, .revealing)
        XCTAssertEqual(snap?.totalCount, 3)
    }

    // MARK: - 5. After abandon mid-lesson

    /// The abandon path is the user navigating away (RootView's
    /// `onExit` callback). The view model is torn down without a
    /// `clear()` — the snapshot stays on disk so the next launch can
    /// resume. We simulate this by reading the last save from the
    /// store after the user has answered and revealed; the snapshot
    /// must still carry totalCount so a fresh launch's
    /// `ResumeLessonCard` doesn't fall back to the shorter copy.
    func testSnapshotSurvivesMidLessonAbandonWithTotalCount() async {
        let store = freshStore()
        let vm = makeViewModel(store: store)
        TestURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/lessons") ?? false { return (200, Self.startBody()) }
            return (200, Self.answerBody())
        }
        await vm.start()
        await vm.answer(1)
        store.flush()
        // Simulate the abandon: the view model is dropped, the store
        // is NOT cleared (matching RootView's onExit → goHome flow,
        // which routes through `.home` without calling `.clear()`).
        // The previously-persisted snapshot must still be loadable
        // with a non-nil totalCount.
        let snap = store.load()
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.totalCount, 3,
            "Abandon mid-lesson must leave totalCount intact for the next launch's resume CTA")
    }
}
