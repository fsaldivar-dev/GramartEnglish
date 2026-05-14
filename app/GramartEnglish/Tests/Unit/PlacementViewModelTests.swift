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

    nonisolated private static func placementStartBody(placementId: String = "11111111-1111-4111-8111-111111111111") -> Data {
        """
        {
          "placementId": "\(placementId)",
          "questions": [
            {"id":"22222222-2222-4222-8222-222222222221","word":"house","options":["A","B","C","D"],"level":"A1"},
            {"id":"22222222-2222-4222-8222-222222222222","word":"eat","options":["A","B","C","D"],"level":"A1"}
          ]
        }
        """.data(using: .utf8)!
    }

    func testStartLoadsQuestions() async throws {
        let vm = makeViewModel()
        TestURLProtocol.handler = { request in
            XCTAssertTrue(request.url?.path.hasSuffix("/placement/start") ?? false)
            return (200, Self.placementStartBody())
        }
        await vm.start()
        guard case .running(let qs, let idx, let answers) = vm.state else {
            return XCTFail("expected running, got \(vm.state)")
        }
        XCTAssertEqual(qs.count, 2)
        XCTAssertEqual(idx, 0)
        XCTAssertEqual(answers.count, 0)
        XCTAssertEqual(vm.progress()?.total, 2)
    }

    func testAnswerAdvancesAndSubmitsAtEnd() async throws {
        let vm = makeViewModel()
        TestURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/placement/start") ?? false {
                return (200, Self.placementStartBody())
            }
            // submit
            let body = """
            {"estimatedLevel":"B1","perLevelScores":{"A1":{"attempted":2,"correct":2}}}
            """.data(using: .utf8)!
            return (200, body)
        }
        await vm.start()
        await vm.answer(0)
        guard case .running(_, let idx, _) = vm.state else {
            return XCTFail("expected still running, got \(vm.state)")
        }
        XCTAssertEqual(idx, 1)
        await vm.answer(1)
        guard case .finished(let result) = vm.state else {
            return XCTFail("expected finished, got \(vm.state)")
        }
        XCTAssertEqual(result.estimatedLevel, "B1")
    }

    func testHttpErrorFlowsToFailedState() async throws {
        let vm = makeViewModel()
        TestURLProtocol.handler = { _ in (500, Data("boom".utf8)) }
        await vm.start()
        guard case .failed(let message) = vm.state else {
            return XCTFail("expected failed, got \(vm.state)")
        }
        XCTAssertTrue(message.contains("HTTP 500"))
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
