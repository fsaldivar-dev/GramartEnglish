import XCTest
@testable import BackendClient

final class BackendClientTests: XCTestCase {

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

    func testHealthDecodesAndSendsCorrelationId() async throws {
        let client = makeClient()
        let expectation = XCTestExpectation(description: "request observed")

        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-correlation-id"), "deadbeef-dead-4dad-8dad-deadbeefdead")
            XCTAssertEqual(request.url?.path, "/v1/health")
            expectation.fulfill()
            let body = """
            { "status": "ok", "version": "1.0.0", "schemaVersion": 1, "ollamaAvailable": true }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }

        let result = try await client.health()
        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.schemaVersion, 1)
        XCTAssertTrue(result.ollamaAvailable)
    }

    func testLevelsReturnsSixCEFR() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            let body = """
            [{"code":"A1","label":"Beginner"},{"code":"A2","label":"Elementary"},
             {"code":"B1","label":"Intermediate"},{"code":"B2","label":"Upper-intermediate"},
             {"code":"C1","label":"Advanced"},{"code":"C2","label":"Proficient"}]
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }
        let levels = try await client.levels()
        XCTAssertEqual(levels.count, 6)
        XCTAssertEqual(levels.first?.code, "A1")
    }

    func testNon2xxThrowsHttpError() async {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("boom".utf8))
        }
        do {
            _ = try await client.health()
            XCTFail("expected error")
        } catch BackendClientError.http(let status, let body) {
            XCTAssertEqual(status, 500)
            XCTAssertEqual(body, "boom")
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) -> (HTTPURLResponse, Data)
    nonisolated(unsafe) static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
