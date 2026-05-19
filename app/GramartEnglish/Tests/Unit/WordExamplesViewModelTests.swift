import XCTest
import BackendClient
@testable import GramartEnglish

@MainActor
final class WordExamplesViewModelTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeViewModel() -> WordExamplesViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = BackendClient(baseURL: URL(string: "http://127.0.0.1:1234")!, session: session) {
            "deadbeef-dead-4dad-8dad-deadbeefdead"
        }
        return WordExamplesViewModel(client: client, word: "eat", level: "A1")
    }

    func testLoadsLLMExamples() async {
        let vm = makeViewModel()
        TestURLProtocol.handler = { _ in
            let body = """
            {"examples":["I eat bread.","She eats apples."],"sourceIds":[1,2],"generatedBy":"llm","fallback":false}
            """.data(using: .utf8)!
            return (200, body)
        }
        await vm.load()
        guard case .loaded(let examples, let fallback) = vm.state else { return XCTFail("expected loaded, got \(vm.state)") }
        XCTAssertEqual(examples.count, 2)
        XCTAssertFalse(fallback)
    }

    func testFallbackOn503StillRendersExamples() async {
        let vm = makeViewModel()
        TestURLProtocol.handler = { _ in
            let body = """
            {"examples":["I eat breakfast every morning."],"sourceIds":[],"generatedBy":"fallback_canonical","fallback":true}
            """.data(using: .utf8)!
            return (503, body)
        }
        await vm.load()
        guard case .loaded(let examples, let fallback) = vm.state else { return XCTFail("expected loaded, got \(vm.state)") }
        XCTAssertEqual(examples.count, 1)
        XCTAssertTrue(fallback)
    }

    func testFailedStateOn500() async {
        let vm = makeViewModel()
        TestURLProtocol.handler = { _ in (500, Data("boom".utf8)) }
        await vm.load()
        guard case .failed(let msg) = vm.state else { return XCTFail("expected failed, got \(vm.state)") }
        XCTAssertTrue(msg.contains("HTTP 500"))
    }
}
