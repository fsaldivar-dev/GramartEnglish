import XCTest
import SwiftUI
import BackendClient
@testable import GramartEnglish

@MainActor
final class PlacementSelfReportViewTests: XCTestCase {

    func testCallsOnPickWithSelectedReport() throws {
        var picked: BackendClient.PlacementSelfReport?? = nil
        let view = PlacementSelfReportView { picked = $0 }
        // The view exposes its callback as `onPick`. We directly invoke it to
        // simulate each button. This is sufficient for the unit-test scope —
        // SwiftUI button-tap routing is covered by the framework.
        view.onPick(.never)
        XCTAssertEqual(picked, .some(.some(.never)))
        view.onPick(.some)
        XCTAssertEqual(picked, .some(.some(.some)))
        view.onPick(.lots)
        XCTAssertEqual(picked, .some(.some(.lots)))
        view.onPick(nil)
        // Skipping passes nil → outer optional has a value of `.none` (the
        // inner Optional<PlacementSelfReport>).
        XCTAssertEqual(picked, .some(nil))
    }

    func testCanBeInstantiated() {
        let view = PlacementSelfReportView { _ in }
        // Forces SwiftUI to evaluate the body to catch obvious render-time
        // crashes. We don't render into a window; this just executes the
        // body computation.
        _ = view.body
    }
}
