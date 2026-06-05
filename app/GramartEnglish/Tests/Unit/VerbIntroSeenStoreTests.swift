import XCTest
@testable import GramartEnglish

final class VerbIntroSeenStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "verbIntroSeenStore.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreshStoreReportsNothingSeen() {
        let store = VerbIntroSeenStore(defaults: defaults)
        XCTAssertFalse(store.hasSeen("go"))
        XCTAssertFalse(store.hasSeen("eat"))
    }

    func testMarkSeenIsObservableImmediately() {
        let store = VerbIntroSeenStore(defaults: defaults)
        store.markSeen("go")
        XCTAssertTrue(store.hasSeen("go"))
        XCTAssertFalse(store.hasSeen("eat"))
    }

    func testMarkSeenIsIdempotent() {
        let store = VerbIntroSeenStore(defaults: defaults)
        store.markSeen("go")
        store.markSeen("go")
        store.markSeen("go")
        XCTAssertTrue(store.hasSeen("go"))
        // No duplication in the underlying storage.
        let stored = defaults.array(forKey: VerbIntroSeenStore.defaultsKey) as? [String]
        XCTAssertEqual(stored, ["go"])
    }

    func testStateSurvivesAcrossInstancesViaUserDefaults() {
        let first = VerbIntroSeenStore(defaults: defaults)
        first.markSeen("eat")
        first.markSeen("go")

        let second = VerbIntroSeenStore(defaults: defaults)
        XCTAssertTrue(second.hasSeen("eat"))
        XCTAssertTrue(second.hasSeen("go"))
        XCTAssertFalse(second.hasSeen("see"))
    }

    func testResetClearsAllSeenState() {
        let store = VerbIntroSeenStore(defaults: defaults)
        store.markSeen("go")
        store.markSeen("eat")
        store.reset()
        XCTAssertFalse(store.hasSeen("go"))
        XCTAssertFalse(store.hasSeen("eat"))
    }

    func testKeyMatchesSpecLockedString() {
        XCTAssertEqual(VerbIntroSeenStore.defaultsKey, "gramart.verbIntro.seen")
    }
}
