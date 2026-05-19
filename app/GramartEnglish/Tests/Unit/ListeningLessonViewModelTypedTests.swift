import XCTest
import BackendClient
import LessonKit
@testable import GramartEnglish

@MainActor
final class ListeningLessonViewModelTypedTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeVM(mode: LessonMode = .listenType) -> LessonViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = BackendClient(baseURL: URL(string: "http://127.0.0.1:1234")!, session: session) {
            "deadbeef-dead-4dad-8dad-deadbeefdead"
        }
        return LessonViewModel(client: client, level: "A1", mode: mode)
    }

    nonisolated private static func startBody() -> Data {
        """
        {
          "lessonId": "11111111-1111-4111-8111-111111111111",
          "mode": "listen_type",
          "questions": [
            {"id":"22222222-2222-4222-8222-222222222221","word":"weather","options":[],"position":0}
          ]
        }
        """.data(using: .utf8)!
    }

    func testTypedCorrectFlowPopulatesEchoOnRevealing() async {
        let vm = makeVM()
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.startBody()) }
            if path.contains("/answers") {
                return (200, """
                {"outcome":"correct","correctIndex":0,"correctOption":"weather","canonicalDefinition":"clima","typedAnswerEcho":"wether"}
                """.data(using: .utf8)!)
            }
            return (404, Data())
        }
        await vm.start()
        await vm.answerTyped("wether")
        guard case .revealing(_, let outcome) = vm.phase else {
            return XCTFail("expected revealing, got \(vm.phase)")
        }
        XCTAssertTrue(outcome.correct)
        XCTAssertEqual(outcome.correctOption, "weather")
        XCTAssertEqual(vm.typedEchoForReveal, "wether")
    }

    func testTypedIncorrectStillExposesEcho() async {
        let vm = makeVM()
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.startBody()) }
            return (200, """
            {"outcome":"incorrect","correctIndex":0,"correctOption":"weather","canonicalDefinition":"clima","typedAnswerEcho":"xxxxx"}
            """.data(using: .utf8)!)
        }
        await vm.start()
        await vm.answerTyped("xxxxx")
        XCTAssertEqual(vm.typedEchoForReveal, "xxxxx")
    }

    func testOptionAnswerClearsTypedEchoFromPriorQuestion() async {
        let vm = makeVM(mode: .listenPickWord)
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.startBody()) }
            return (200, """
            {"outcome":"correct","correctIndex":0,"correctOption":"weather","canonicalDefinition":"clima"}
            """.data(using: .utf8)!)
        }
        await vm.start()
        await vm.answer(0)
        // Option-based answer must leave `typedEchoForReveal` nil even if a previous
        // listen_type lesson left state behind (defensive — VM is fresh here).
        XCTAssertNil(vm.typedEchoForReveal)
    }
}
