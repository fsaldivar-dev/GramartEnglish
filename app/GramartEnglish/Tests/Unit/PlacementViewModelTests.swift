import XCTest
import BackendClient
@testable import GramartEnglish

@MainActor
final class PlacementViewModelTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeViewModel() -> PlacementViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = BackendClient(baseURL: URL(string: "http://127.0.0.1:1234")!, session: session) {
            "deadbeef-dead-4dad-8dad-deadbeefdead"
        }
        return PlacementViewModel(client: client)
    }

    nonisolated private static func adaptiveStartBody(
        placementId: String = "11111111-1111-4111-8111-111111111111",
        questionId: String = "22222222-2222-4222-8222-222222222221"
    ) -> Data {
        """
        {
          "placementId": "\(placementId)",
          "question": {"id":"\(questionId)","word":"house","options":["A","B","C","D"],"level":"A1"},
          "progress": {"current": 1, "max": 30},
          "algorithmVersion": "v2"
        }
        """.data(using: .utf8)!
    }

    nonisolated private static func continueBody(
        nextQuestionId: String,
        current: Int
    ) -> Data {
        """
        {
          "kind": "continue",
          "question": {"id":"\(nextQuestionId)","word":"eat","options":["A","B","C","D"],"level":"A2"},
          "progress": {"current": \(current), "max": 30}
        }
        """.data(using: .utf8)!
    }

    nonisolated private static func doneBody() -> Data {
        """
        {
          "kind": "done",
          "result": {
            "estimatedLevel": "B1",
            "perLevelScores": {"A1":{"attempted":2,"correct":2}},
            "algorithmVersion": "v2",
            "itemsAdministered": 14
          }
        }
        """.data(using: .utf8)!
    }

    func testInitialStateIsSelfReport() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.state, .selfReport)
    }

    func testStartLoadsFirstQuestion() async throws {
        let vm = makeViewModel()
        TestURLProtocol.handler = { request in
            XCTAssertTrue(request.url?.path.hasSuffix("/placement/start") ?? false)
            // Confirm the X-Client-Version header is set on outgoing requests.
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-client-version"), BackendClient.clientVersion)
            return (200, Self.adaptiveStartBody())
        }
        await vm.start(selfReport: .never)
        guard case let .question(current, max, q) = vm.state else {
            return XCTFail("expected .question, got \(vm.state)")
        }
        XCTAssertEqual(current, 1)
        XCTAssertEqual(max, 30)
        XCTAssertEqual(q.word, "house")
        XCTAssertEqual(vm.progress()?.total, 30)
        XCTAssertEqual(vm.currentQuestion()?.id, "22222222-2222-4222-8222-222222222221")
    }

    func testAnswerContinuesToNextQuestion() async throws {
        let vm = makeViewModel()
        TestURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/placement/start") ?? false {
                return (200, Self.adaptiveStartBody())
            }
            // /answer → continue
            return (200, Self.continueBody(nextQuestionId: "33333333-3333-4333-8333-333333333333", current: 2))
        }
        await vm.start(selfReport: .some)
        await vm.answer(0)
        guard case let .question(current, _, q) = vm.state else {
            return XCTFail("expected .question, got \(vm.state)")
        }
        XCTAssertEqual(current, 2)
        XCTAssertEqual(q.id, "33333333-3333-4333-8333-333333333333")
    }

    func testAnswerTerminalTransitionsToFinished() async throws {
        let vm = makeViewModel()
        TestURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/placement/start") ?? false {
                return (200, Self.adaptiveStartBody())
            }
            return (200, Self.doneBody())
        }
        await vm.start(selfReport: .lots)
        await vm.answer(2)
        guard case let .finished(result) = vm.state else {
            return XCTFail("expected finished, got \(vm.state)")
        }
        XCTAssertEqual(result.estimatedLevel, "B1")
        XCTAssertEqual(result.algorithmVersion, "v2")
        XCTAssertEqual(result.itemsAdministered, 14)
    }

    func testHttpErrorFlowsToFailedState() async throws {
        let vm = makeViewModel()
        TestURLProtocol.handler = { _ in (500, Data("boom".utf8)) }
        await vm.start(selfReport: nil)
        guard case .failed(let message) = vm.state else {
            return XCTFail("expected failed, got \(vm.state)")
        }
        XCTAssertTrue(message.contains("HTTP 500"))
    }

    func testResetReturnsToSelfReport() async throws {
        let vm = makeViewModel()
        TestURLProtocol.handler = { _ in (200, Self.adaptiveStartBody()) }
        await vm.start(selfReport: .never)
        XCTAssertNotEqual(vm.state, .selfReport)
        vm.reset()
        XCTAssertEqual(vm.state, .selfReport)
    }
}

// MARK: - TestURLProtocol

final class TestURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) -> (Int, Data)
    nonisolated(unsafe) static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = TestURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
