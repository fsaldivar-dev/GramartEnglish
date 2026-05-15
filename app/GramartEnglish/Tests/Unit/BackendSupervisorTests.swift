import XCTest
@testable import GramartEnglish

final class BackendSupervisorTests: XCTestCase {

    func testParsesValidHandshake() throws {
        let line = #"{"port": 47731, "pid": 1234, "version": "1.0.0"}"#
        let handshake = try BackendSupervisor.parseHandshake(line)
        XCTAssertEqual(handshake.port, 47731)
        XCTAssertEqual(handshake.pid, 1234)
        XCTAssertEqual(handshake.version, "1.0.0")
    }

    func testRejectsMalformedHandshake() {
        XCTAssertThrowsError(try BackendSupervisor.parseHandshake("not json"))
        XCTAssertThrowsError(try BackendSupervisor.parseHandshake(#"{"port":47731}"#))
        XCTAssertThrowsError(try BackendSupervisor.parseHandshake(""))
    }
}
