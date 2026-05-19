import XCTest
@testable import BackendClient

final class BackendClientModesTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeClient(baseURL: URL = URL(string: "http://127.0.0.1:1234")!) -> BackendClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return BackendClient(baseURL: baseURL, session: session) { "deadbeef-dead-4dad-8dad-deadbeefdead" }
    }

    private func bodyJSON(_ request: URLRequest) -> [String: Any]? {
        // URLProtocol receives the request before httpBody is moved to httpBodyStream.
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // MARK: - startLesson(mode:)

    func testStartLessonSendsModeInBody() async throws {
        let client = makeClient()
        let observed = XCTestExpectation(description: "request observed")

        MockURLProtocol.handler = { [weak self] request in
            XCTAssertEqual(request.url?.path, "/v1/lessons")
            let body = self?.bodyJSON(request) ?? [:]
            XCTAssertEqual(body["level"] as? String, "A2")
            XCTAssertEqual(body["mode"] as? String, "listen_pick_word")
            observed.fulfill()
            let payload = """
            {"lessonId":"L1","mode":"listen_pick_word","questions":[]}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let result = try await client.startLesson(level: "A2", mode: "listen_pick_word")
        await fulfillment(of: [observed], timeout: 1)
        XCTAssertEqual(result.lessonId, "L1")
        XCTAssertEqual(result.mode, "listen_pick_word")
    }

    func testStartLessonOmitsModeKeyWhenNil() async throws {
        let client = makeClient()
        let observed = XCTestExpectation(description: "request observed")
        MockURLProtocol.handler = { [weak self] request in
            let body = self?.bodyJSON(request) ?? [:]
            XCTAssertEqual(body["level"] as? String, "A1")
            XCTAssertNil(body["mode"], "mode key should be absent when nil so server applies its default")
            observed.fulfill()
            let payload = """
            {"lessonId":"L2","mode":"read_pick_meaning","questions":[]}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        _ = try await client.startLesson(level: "A1")
        await fulfillment(of: [observed], timeout: 1)
    }

    // MARK: - answerLesson(typedAnswer:)

    func testAnswerLessonTypedRoundTrip() async throws {
        let client = makeClient()
        let observed = XCTestExpectation(description: "request observed")

        MockURLProtocol.handler = { [weak self] request in
            XCTAssertEqual(request.url?.path, "/v1/lessons/L1/answers")
            let body = self?.bodyJSON(request) ?? [:]
            XCTAssertEqual(body["typedAnswer"] as? String, "wether")
            XCTAssertEqual(body["questionId"] as? String, "Q1")
            XCTAssertEqual(body["answerMs"] as? Int, 1500)
            XCTAssertNil(body["optionIndex"], "optionIndex must be absent in typed mode")
            observed.fulfill()
            let payload = """
            {"outcome":"correct","correctIndex":0,"correctOption":"weather","canonicalDefinition":"clima","typedAnswerEcho":"wether"}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let result = try await client.answerLesson(lessonId: "L1", questionId: "Q1", typedAnswer: "wether", answerMs: 1500)
        await fulfillment(of: [observed], timeout: 1)
        XCTAssertEqual(result.outcome, .correct)
        XCTAssertEqual(result.typedAnswerEcho, "wether")
        XCTAssertEqual(result.correctOption, "weather")
    }

    func testAnswerLessonOptionIndexOmitsTypedAnswer() async throws {
        let client = makeClient()
        let observed = XCTestExpectation(description: "request observed")
        MockURLProtocol.handler = { [weak self] request in
            let body = self?.bodyJSON(request) ?? [:]
            XCTAssertEqual(body["optionIndex"] as? Int, 2)
            XCTAssertNil(body["typedAnswer"])
            observed.fulfill()
            let payload = """
            {"outcome":"incorrect","correctIndex":0,"correctOption":"cat","canonicalDefinition":"gato"}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let result = try await client.answerLesson(lessonId: "L1", questionId: "Q1", optionIndex: 2, answerMs: 800)
        await fulfillment(of: [observed], timeout: 1)
        XCTAssertEqual(result.outcome, .incorrect)
        XCTAssertNil(result.typedAnswerEcho)
    }

    // MARK: - progress() with new fields

    func testProgressDecodesPerModeAndRecommendedMode() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            let payload = """
            {
              "currentLevel": "A2",
              "lessonsCompleted": 3,
              "masteredCount": 5,
              "toReviewCount": 7,
              "lastLesson": null,
              "resumable": null,
              "perModeMastered": {
                "read_pick_meaning": 3,
                "listen_pick_word": 2,
                "listen_pick_meaning": 0,
                "listen_type": 0
              },
              "recommendedMode": "listen_pick_meaning"
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let result = try await client.progress()
        XCTAssertEqual(result.perModeMastered?["read_pick_meaning"], 3)
        XCTAssertEqual(result.perModeMastered?["listen_pick_word"], 2)
        XCTAssertEqual(result.recommendedMode, "listen_pick_meaning")
    }

    func testProgressTolaratesMissingNewFieldsForBackwardCompat() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            // An older server response (without perModeMastered/recommendedMode).
            let payload = """
            {"currentLevel":"A1","lessonsCompleted":0,"masteredCount":0,"toReviewCount":0,"lastLesson":null,"resumable":null}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let result = try await client.progress()
        XCTAssertNil(result.perModeMastered)
        XCTAssertNil(result.recommendedMode)
    }

    // MARK: - patchMePreferredMode

    func testPatchMePreferredModeSendsPreferredMode() async throws {
        let client = makeClient()
        let observed = XCTestExpectation(description: "request observed")
        MockURLProtocol.handler = { [weak self] request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/v1/me")
            let body = self?.bodyJSON(request) ?? [:]
            XCTAssertEqual(body["preferredMode"] as? String, "listen_type")
            XCTAssertNil(body["currentLevel"])
            observed.fulfill()
            let payload = """
            {"id":"u1","currentLevel":"A2","createdAt":"2026-05-14T00:00:00.000Z","preferredMode":"listen_type"}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let user = try await client.patchMePreferredMode("listen_type")
        await fulfillment(of: [observed], timeout: 1)
        XCTAssertEqual(user.preferredMode, "listen_type")
    }
}
