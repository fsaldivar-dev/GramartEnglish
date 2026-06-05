import XCTest
import BackendClient
import LessonKit
@testable import GramartEnglish

@MainActor
final class LessonViewModelIntroGatingTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: VerbIntroSeenStore!

    override func setUp() {
        super.setUp()
        suiteName = "lessonVMGating.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = VerbIntroSeenStore(defaults: defaults)
    }

    override func tearDown() {
        TestURLProtocol.handler = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeViewModel(mode: LessonMode) -> LessonViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = BackendClient(baseURL: URL(string: "http://127.0.0.1:1234")!, session: session) {
            "deadbeef-dead-4dad-8dad-deadbeefdead"
        }
        return LessonViewModel(client: client, level: "A2", mode: mode, verbIntroSeen: store)
    }

    nonisolated private static func conjugationLessonBody() -> Data {
        """
        {
          "lessonId": "11111111-1111-4111-8111-111111111111",
          "mode": "conjugate_pick_form",
          "questions": [
            {"id":"22222222-2222-4222-8222-222222222221","word":"go","options":["went","goed","go","gone"],"position":0,
             "prompt":"Pasado simple de **ir**","verbBase":"go","targetTense":"simple_past"},
            {"id":"22222222-2222-4222-8222-222222222222","word":"eat","options":["ate","eated","eat","eaten"],"position":1,
             "prompt":"Pasado simple de **comer**","verbBase":"eat","targetTense":"simple_past"}
          ]
        }
        """.data(using: .utf8)!
    }

    nonisolated private static func readLessonBody() -> Data {
        """
        {
          "lessonId": "11111111-1111-4111-8111-111111111111",
          "questions": [
            {"id":"22222222-2222-4222-8222-222222222221","word":"go","options":["A","B","C","D"],"position":0}
          ]
        }
        """.data(using: .utf8)!
    }

    nonisolated private static func verbIntroBody(base: String) -> Data {
        """
        {
          "base": "\(base)",
          "es": "ir",
          "exampleEs": "Ayer ___ al cine con mi hermana.",
          "exampleEsFilled": "Ayer fui al cine con mi hermana.",
          "exampleEn": "Yesterday I went to the movies with my sister.",
          "audioBase": "\(base).mp3"
        }
        """.data(using: .utf8)!
    }

    // MARK: - The happy path: unseen verb shows the intro card

    func testUnseenVerbInConjugationModeSetsPendingIntro() async {
        let vm = makeViewModel(mode: .conjugatePickForm)
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.conjugationLessonBody()) }
            if path.contains("/verbs/go/intro") { return (200, Self.verbIntroBody(base: "go")) }
            return (404, Data())
        }
        await vm.start()
        XCTAssertNotNil(vm.pendingIntro)
        XCTAssertEqual(vm.pendingIntro?.base, "go")
    }

    // MARK: - The skip path: seen verb goes straight to question

    func testSeenVerbInConjugationModeDoesNotFetchIntro() async {
        store.markSeen("go")
        let vm = makeViewModel(mode: .conjugatePickForm)
        var introCalled = false
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.conjugationLessonBody()) }
            if path.contains("/intro") { introCalled = true; return (200, Self.verbIntroBody(base: "go")) }
            return (404, Data())
        }
        await vm.start()
        XCTAssertNil(vm.pendingIntro)
        XCTAssertFalse(introCalled, "intro endpoint must not be called when verb is already seen")
    }

    // MARK: - Mode scope: non-conjugate modes never trigger

    func testReadPickMeaningModeNeverFetchesIntroEvenForVerbWord() async {
        let vm = makeViewModel(mode: .readPickMeaning)
        var introCalled = false
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.readLessonBody()) }
            if path.contains("/intro") { introCalled = true; return (200, Self.verbIntroBody(base: "go")) }
            return (404, Data())
        }
        await vm.start()
        XCTAssertNil(vm.pendingIntro)
        XCTAssertFalse(introCalled, "non-conjugate modes must never call /verbs/:base/intro")
    }

    // MARK: - Dismissal marks seen + clears state

    func testDismissVerbIntroMarksSeenAndClearsPendingIntro() async {
        let vm = makeViewModel(mode: .conjugatePickForm)
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.conjugationLessonBody()) }
            if path.contains("/verbs/go/intro") { return (200, Self.verbIntroBody(base: "go")) }
            return (404, Data())
        }
        await vm.start()
        XCTAssertNotNil(vm.pendingIntro)

        vm.dismissVerbIntro()

        XCTAssertNil(vm.pendingIntro)
        XCTAssertTrue(store.hasSeen("go"))
    }

    // MARK: - 404 from intro endpoint degrades gracefully

    func testIntroFetch404DoesNotBlockQuestion() async {
        let vm = makeViewModel(mode: .conjugatePickForm)
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.conjugationLessonBody()) }
            if path.contains("/intro") { return (404, "{\"code\":\"verb_not_found\",\"message\":\"x\"}".data(using: .utf8)!) }
            return (404, Data())
        }
        await vm.start()
        XCTAssertNil(vm.pendingIntro)
        if case .answering = vm.phase {
            // ok — question view will render
        } else {
            XCTFail("expected .answering phase, got \(vm.phase)")
        }
    }
}
