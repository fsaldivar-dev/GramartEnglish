import XCTest
@testable import BackendClient

/// F006 — contract tests for `GET /v1/verbs/:base/intro`.
final class VerbIntroTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeClient() -> BackendClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return BackendClient(baseURL: URL(string: "http://127.0.0.1:1234")!, session: session) {
            "deadbeef-dead-4dad-8dad-deadbeefdead"
        }
    }

    func testFetchVerbIntroDecodes200() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/verbs/go/intro")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-client-version"), "1.8.0")
            let body = """
            {
              "base": "go",
              "es": "ir",
              "exampleEs": "Ayer ___ al cine con mi hermana.",
              "exampleEsFilled": "Ayer fui al cine con mi hermana.",
              "exampleEn": "Yesterday I went to the movies with my sister.",
              "audioBase": "go.mp3"
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }
        let intro = try await client.fetchVerbIntro(base: "go")
        XCTAssertNotNil(intro)
        XCTAssertEqual(intro?.base, "go")
        XCTAssertEqual(intro?.es, "ir")
        XCTAssertEqual(intro?.audioBase, "go.mp3")
        XCTAssertTrue(intro?.exampleEs.contains("___") ?? false)
        // v1.7.0 patch (Blocker 1): the filled form must NOT carry the slot
        // and must include the conjugated Spanish form.
        XCTAssertFalse(intro?.exampleEsFilled.contains("___") ?? true)
        XCTAssertTrue(intro?.exampleEsFilled.lowercased().contains("fui") ?? false)
        XCTAssertTrue(intro?.exampleEn.lowercased().contains("went") ?? false)
    }

    func testFetchVerbIntroReturnsNilOn404() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = #"{"code":"verb_not_found","message":"unknown verb base: zzz"}"#.data(using: .utf8)!
            return (response, body)
        }
        let intro = try await client.fetchVerbIntro(base: "zzz")
        XCTAssertNil(intro)
    }

    func testFetchVerbIntroPropagatesNon404Errors() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        do {
            _ = try await client.fetchVerbIntro(base: "go")
            XCTFail("expected HTTP error to propagate")
        } catch {
            // expected
        }
    }

    func testClientVersionIsBumpedTo180() {
        XCTAssertEqual(BackendClient.clientVersion, "1.8.0")
    }
}
