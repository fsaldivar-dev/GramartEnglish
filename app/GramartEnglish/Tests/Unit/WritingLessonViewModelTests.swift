import XCTest
import BackendClient
import LessonKit
@testable import GramartEnglish

@MainActor
final class WritingLessonViewModelTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeVM(mode: LessonMode = .writePickWord) -> LessonViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = BackendClient(baseURL: URL(string: "http://127.0.0.1:1234")!, session: session) {
            "deadbeef-dead-4dad-8dad-deadbeefdead"
        }
        return LessonViewModel(client: client, level: "A1", mode: mode)
    }

    nonisolated private static func startBodyWritePickWord() -> Data {
        // Server sends prompt for write modes (v1.3 contract).
        """
        {
          "lessonId": "11111111-1111-4111-8111-111111111111",
          "mode": "write_pick_word",
          "questions": [
            {"id":"22222222-2222-4222-8222-222222222221","word":"weather","options":["weather","kitchen","market","advice"],"position":0,"prompt":"clima / tiempo"},
            {"id":"22222222-2222-4222-8222-222222222222","word":"market","options":["market","beach","weather","language"],"position":1,"prompt":"mercado"}
          ]
        }
        """.data(using: .utf8)!
    }

    func testStartCarriesPromptThroughToLessonState() async {
        let vm = makeVM()
        TestURLProtocol.handler = { _ in (200, Self.startBodyWritePickWord()) }
        await vm.start()
        guard case .answering(let state) = vm.phase else {
            return XCTFail("expected answering, got \(vm.phase)")
        }
        XCTAssertEqual(state.currentQuestion?.prompt, "clima / tiempo")
        XCTAssertEqual(state.currentQuestion?.word, "weather")
        XCTAssertEqual(state.questions.last?.prompt, "mercado")
    }

    func testStartSendsModeInBody() async {
        let vm = makeVM()
        let observed = TestFlag()
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
                   json["mode"] as? String == "write_pick_word" {
                    observed.value = true
                }
            }
            return (200, Self.startBodyWritePickWord())
        }
        await vm.start()
        XCTAssertTrue(observed.value, "client must send mode=write_pick_word in request body")
        XCTAssertEqual(vm.mode, .writePickWord)
    }
}
