import XCTest
import BackendClient
import LessonKit
@testable import GramartEnglish

@MainActor
final class LessonViewModelTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeViewModel() -> LessonViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = BackendClient(baseURL: URL(string: "http://127.0.0.1:1234")!, session: session) {
            "deadbeef-dead-4dad-8dad-deadbeefdead"
        }
        return LessonViewModel(client: client, level: "A1")
    }

    nonisolated private static func startBody() -> Data {
        // 2 questions so we can test answer + complete quickly.
        """
        {
          "lessonId": "11111111-1111-4111-8111-111111111111",
          "questions": [
            {"id":"22222222-2222-4222-8222-222222222221","word":"house","options":["A","B","C","D"],"position":0},
            {"id":"22222222-2222-4222-8222-222222222222","word":"eat","options":["A","B","C","D"],"position":1}
          ]
        }
        """.data(using: .utf8)!
    }

    nonisolated private static func answerBody(correct: Bool) -> Data {
        """
        {"outcome":"\(correct ? "correct" : "incorrect")","correctIndex":1,"correctOption":"B","canonicalDefinition":"def"}
        """.data(using: .utf8)!
    }

    nonisolated private static func summaryBody() -> Data {
        """
        {"lessonId":"11111111-1111-4111-8111-111111111111","score":1,"skipped":0,"wrong":1,"total":2,"missedWords":[{"word":"eat","canonicalDefinition":"to consume food","outcome":"incorrect"}]}
        """.data(using: .utf8)!
    }

    func testStartLoadsLesson() async {
        let vm = makeViewModel()
        TestURLProtocol.handler = { request in
            XCTAssertTrue(request.url?.path.hasSuffix("/lessons") ?? false)
            return (200, Self.startBody())
        }
        await vm.start()
        guard case .answering(let state) = vm.phase else { return XCTFail("expected answering, got \(vm.phase)") }
        XCTAssertEqual(state.questions.count, 2)
        XCTAssertEqual(state.currentQuestion?.word, "house")
    }

    func testAnswerRevealsOutcomeAndNextAdvances() async {
        let vm = makeViewModel()
        TestURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/lessons") ?? false { return (200, Self.startBody()) }
            return (200, Self.answerBody(correct: true))
        }
        await vm.start()
        await vm.answer(1)
        guard case .revealing(_, let outcome) = vm.phase else { return XCTFail("expected revealing, got \(vm.phase)") }
        XCTAssertTrue(outcome.correct)
        XCTAssertEqual(outcome.correctIndex, 1)
        await vm.next()
        guard case .answering(let state) = vm.phase else { return XCTFail("expected answering after next, got \(vm.phase)") }
        XCTAssertEqual(state.currentQuestion?.word, "eat")
    }

    func testLastNextTriggersCompletionAndSummary() async {
        let vm = makeViewModel()
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.startBody()) }
            if path.contains("/answers") { return (200, Self.answerBody(correct: true)) }
            if path.contains("/complete") { return (200, Self.summaryBody()) }
            return (404, Data())
        }
        await vm.start()
        await vm.answer(1)
        await vm.next()
        await vm.answer(2)
        await vm.next() // should complete + fetch summary
        guard case .summary(let summary) = vm.phase else { return XCTFail("expected summary, got \(vm.phase)") }
        XCTAssertEqual(summary.score, 1)
        XCTAssertEqual(summary.total, 2)
    }

    func testHttpErrorOnStartFlowsToFailed() async {
        let vm = makeViewModel()
        TestURLProtocol.handler = { _ in (500, Data("boom".utf8)) }
        await vm.start()
        guard case .failed(let msg) = vm.phase else { return XCTFail("expected failed, got \(vm.phase)") }
        XCTAssertTrue(msg.contains("HTTP 500"))
    }
}
