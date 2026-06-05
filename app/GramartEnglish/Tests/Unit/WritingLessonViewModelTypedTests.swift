import XCTest
import BackendClient
import LessonKit
@testable import GramartEnglish

@MainActor
final class WritingLessonViewModelTypedTests: XCTestCase {

    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeVM(mode: LessonMode = .writeTypeWord) -> LessonViewModel {
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
          "mode": "write_type_word",
          "questions": [
            {"id":"22222222-2222-4222-8222-222222222221","word":"weather","options":[],"position":0,"prompt":"clima / tiempo"}
          ]
        }
        """.data(using: .utf8)!
    }

    func testAnswerTypedForwardsHintUsedFlag() async {
        let vm = makeVM()
        let observedHintUsed = TestFlag()
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.startBody()) }
            if path.contains("/answers"), let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var data = Data()
                var buf = [UInt8](repeating: 0, count: 2048)
                while stream.hasBytesAvailable {
                    let n = stream.read(&buf, maxLength: buf.count)
                    if n <= 0 { break }
                    data.append(buf, count: n)
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["hintUsed"] as? Bool == true {
                    observedHintUsed.value = true
                }
                return (200, """
                {"outcome":"correct","correctIndex":0,"correctOption":"weather","canonicalDefinition":"clima","typedAnswerEcho":"weather"}
                """.data(using: .utf8)!)
            }
            return (404, Data())
        }
        await vm.start()
        await vm.answerTyped("weather", hintUsed: true)
        XCTAssertTrue(observedHintUsed.value, "client must include hintUsed=true in the answer request body")
    }

    func testAnswerTypedWithoutHintOmitsFlag() async {
        let vm = makeVM()
        let sawHintFlag = TestFlag()
        TestURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/lessons") { return (200, Self.startBody()) }
            if path.contains("/answers"), let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var data = Data()
                var buf = [UInt8](repeating: 0, count: 2048)
                while stream.hasBytesAvailable {
                    let n = stream.read(&buf, maxLength: buf.count)
                    if n <= 0 { break }
                    data.append(buf, count: n)
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["hintUsed"] != nil {
                    sawHintFlag.value = true
                }
                return (200, """
                {"outcome":"correct","correctIndex":0,"correctOption":"weather","canonicalDefinition":"clima","typedAnswerEcho":"weather"}
                """.data(using: .utf8)!)
            }
            return (404, Data())
        }
        await vm.start()
        await vm.answerTyped("weather")  // default hintUsed = false → omit from body
        XCTAssertFalse(sawHintFlag.value, "hintUsed key should be absent when not used (compact body)")
    }
}
