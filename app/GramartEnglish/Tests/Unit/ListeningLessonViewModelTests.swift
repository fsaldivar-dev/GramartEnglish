import XCTest
import BackendClient
import LessonKit
@testable import GramartEnglish

@MainActor
final class ListeningLessonViewModelTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeViewModel(mode: LessonMode = .listenPickWord) -> LessonViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = BackendClient(baseURL: URL(string: "http://127.0.0.1:1234")!, session: session) {
            "deadbeef-dead-4dad-8dad-deadbeefdead"
        }
        return LessonViewModel(client: client, level: "A1", mode: mode)
    }

    nonisolated private static func startBodyListenPickWord() -> Data {
        """
        {
          "lessonId": "11111111-1111-4111-8111-111111111111",
          "mode": "listen_pick_word",
          "questions": [
            {"id":"22222222-2222-4222-8222-222222222221","word":"weather","options":["weather","language","dangerous","important"],"position":0},
            {"id":"22222222-2222-4222-8222-222222222222","word":"eat","options":["A","B","C","D"],"position":1}
          ]
        }
        """.data(using: .utf8)!
    }

    nonisolated private static func answerBody(correct: Bool, typedEcho: String? = nil) -> Data {
        let echo = typedEcho.map { ",\"typedAnswerEcho\":\"\($0)\"" } ?? ""
        return """
        {"outcome":"\(correct ? "correct" : "incorrect")","correctIndex":0,"correctOption":"weather","canonicalDefinition":"clima"\(echo)}
        """.data(using: .utf8)!
    }

    func testStartSendsModeInBody() async {
        let vm = makeViewModel(mode: .listenPickWord)
        let observed = XCTestExpectation(description: "mode in body")
        TestURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/lessons") == true,
               let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var data = Data()
                var buf = [UInt8](repeating: 0, count: 2048)
                while stream.hasBytesAvailable {
                    let n = stream.read(&buf, maxLength: buf.count)
                    if n <= 0 { break }
                    data.append(buf, count: n)
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["mode"] as? String == "listen_pick_word" {
                    observed.fulfill()
                }
            }
            return (200, Self.startBodyListenPickWord())
        }
        await vm.start()
        await fulfillment(of: [observed], timeout: 1)
        XCTAssertEqual(vm.mode, .listenPickWord)
    }

    func testRevealExposesEnglishCorrectOptionInListenPickWord() async {
        let vm = makeViewModel(mode: .listenPickWord)
        TestURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/lessons") == true {
                return (200, Self.startBodyListenPickWord())
            }
            return (200, Self.answerBody(correct: true))
        }
        await vm.start()
        await vm.answer(0)
        guard case .revealing(_, let outcome) = vm.phase else {
            return XCTFail("expected revealing, got \(vm.phase)")
        }
        XCTAssertTrue(outcome.correct)
        XCTAssertEqual(outcome.correctOption, "weather", "listen_pick_word should reveal the English word")
    }

    func testAnswerTypedSendsTypedAnswerAndCapturesEcho() async {
        let vm = makeViewModel(mode: .listenType)
        // `TestURLProtocol.handler` is `@Sendable`, so the closure can run on
        // any thread. Capturing a `var Bool` and mutating it triggers
        // "mutation of captured var in concurrently-executing code" on Swift
        // 5.9 strict concurrency. A class-wrapped flag is the standard fix.
        let sawTypedBody = TestFlag()
        TestURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/lessons") == true {
                return (200, Self.startBodyListenPickWord())
            }
            if request.url?.path.contains("/answers") == true,
               let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var data = Data()
                var buf = [UInt8](repeating: 0, count: 2048)
                while stream.hasBytesAvailable {
                    let n = stream.read(&buf, maxLength: buf.count)
                    if n <= 0 { break }
                    data.append(buf, count: n)
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["typedAnswer"] as? String == "wether",
                   json["optionIndex"] == nil {
                    sawTypedBody.value = true
                }
                return (200, Self.answerBody(correct: true, typedEcho: "wether"))
            }
            return (404, Data())
        }
        await vm.start()
        await vm.answerTyped("  wether  ") // trimming
        XCTAssertTrue(sawTypedBody.value, "request body must carry typedAnswer and no optionIndex")
        XCTAssertEqual(vm.typedEchoForReveal, "wether")
        guard case .revealing(_, let outcome) = vm.phase else {
            return XCTFail("expected revealing")
        }
        XCTAssertTrue(outcome.correct)
    }

    func testEmptyTypedAnswerFallsThroughToSkip() async {
        let vm = makeViewModel(mode: .listenType)
        let sawSkip = TestFlag()
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.startBodyListenPickWord()) }
            if path.contains("/skip") {
                sawSkip.value = true
                return (200, """
                {"outcome":"skipped","correctIndex":0,"correctOption":"weather","canonicalDefinition":"clima"}
                """.data(using: .utf8)!)
            }
            return (404, Data())
        }
        await vm.start()
        await vm.answerTyped("   ")
        XCTAssertTrue(sawSkip.value, "empty typed input should route to /skip")
        XCTAssertNil(vm.typedEchoForReveal)
    }
}

/// Mutable flag wrapped in a class so it can be safely captured by
/// `@Sendable` URL-mock handlers without tripping Swift 5.9 strict-concurrency
/// checks on captured `var`s.
final class TestFlag: @unchecked Sendable {
    var value: Bool = false
}
