import XCTest
@testable import GramartEnglish

final class LessonStateStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LessonStateStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private func makeStore() -> LessonStateStore {
        let store = LessonStateStore(directory: tempDir)
        store.debounceOverrideMillis = 0 // flush immediately in tests
        return store
    }

    private func sample(phase: LessonStateSnapshot.Phase = .answering,
                        index: Int = 0) -> LessonStateSnapshot {
        LessonStateSnapshot(
            lessonId: "lesson-abc",
            mode: "read_pick_meaning",
            level: "A2",
            phase: phase,
            currentQuestionIndex: index,
            answeredCount: index
        )
    }

    func testLoadReturnsNilWhenNoSnapshotPersisted() {
        let store = makeStore()
        XCTAssertNil(store.load())
    }

    func testRoundTripPreservesAllFields() {
        let store = makeStore()
        let snap = sample(phase: .revealing, index: 4)
        store.save(snap)
        store.flush()

        let loaded = store.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.lessonId, "lesson-abc")
        XCTAssertEqual(loaded?.mode, "read_pick_meaning")
        XCTAssertEqual(loaded?.level, "A2")
        XCTAssertEqual(loaded?.phase, .revealing)
        XCTAssertEqual(loaded?.currentQuestionIndex, 4)
        XCTAssertEqual(loaded?.answeredCount, 4)
    }

    func testClearRemovesPersistedSnapshot() {
        let store = makeStore()
        store.save(sample())
        store.flush()
        XCTAssertNotNil(store.load())

        store.clear()
        XCTAssertNil(store.load())
    }

    func testCorruptFileIsDeletedAndLoadReturnsNil() throws {
        let store = makeStore()
        // Write garbage directly to the file the store would use.
        let fileURL = tempDir.appendingPathComponent("lesson-state.json")
        try Data("not valid json {{{".utf8).write(to: fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        XCTAssertNil(store.load())
        // Corrupt file is deleted so the next launch doesn't repeatedly try
        // to parse it.
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testConcurrentSavesAllReachDisk_LastOneWins() {
        let store = makeStore()
        // Hammer save() from multiple threads. Without atomic writes the
        // final read could see truncated JSON; with our `replaceItemAt`
        // we expect one well-formed snapshot at the end whose
        // currentQuestionIndex matches one of the saves.
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        for i in 0..<50 {
            group.enter()
            queue.async {
                store.save(self.sample(index: i))
                group.leave()
            }
        }
        group.wait()
        store.flush()

        let loaded = store.load()
        XCTAssertNotNil(loaded, "Atomic writes must leave a parseable JSON behind")
        XCTAssertTrue((0..<50).contains(loaded?.currentQuestionIndex ?? -1))
    }

    func testDebouncedSavesCoalesce() {
        // With a real debounce window the file should still end up holding
        // the most recent save once flush() lands.
        let store = LessonStateStore(directory: tempDir)
        store.debounceOverrideMillis = 30
        store.save(sample(index: 1))
        store.save(sample(index: 2))
        store.save(sample(index: 3))
        // Wait for the debounce to elapse.
        let exp = expectation(description: "debounce flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        let loaded = store.load()
        XCTAssertEqual(loaded?.currentQuestionIndex, 3)
    }
}
