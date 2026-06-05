import XCTest
import SwiftUI
@testable import GramartEnglish

/// F007 (v1.8.0). Compile-time + value pin for the design tokens introduced
/// in this release. The tokens are deliberately tiny in scope (Mariana ruled
/// out a full propagation this cycle), so this test serves as a contract:
/// removing or renaming a token will fail loudly here before downstream
/// surfaces start referencing it.
///
/// We do NOT pin Semantic.* color VALUES — they're fallbacks until the
/// asset-catalog migration in v1.9. We DO pin that the symbols exist and
/// are non-clear, so a future refactor can't accidentally null one out.
final class DesignTokenContractTests: XCTestCase {

    func testSpacingScaleIsPinned() {
        XCTAssertEqual(Spacing.xxs, 4)
        XCTAssertEqual(Spacing.xs, 8)
        XCTAssertEqual(Spacing.sm, 12)
        XCTAssertEqual(Spacing.md, 16)
        XCTAssertEqual(Spacing.lg, 24)
        XCTAssertEqual(Spacing.xl, 32)
    }

    func testSpacingScaleIsMonotonic() {
        // A future contributor renaming a step would obviously be caught
        // by the test above; this one catches the subtler bug of
        // swapping two values (e.g. xs=12, sm=8) which still compiles
        // but inverts the scale.
        XCTAssertLessThan(Spacing.xxs, Spacing.xs)
        XCTAssertLessThan(Spacing.xs, Spacing.sm)
        XCTAssertLessThan(Spacing.sm, Spacing.md)
        XCTAssertLessThan(Spacing.md, Spacing.lg)
        XCTAssertLessThan(Spacing.lg, Spacing.xl)
    }

    func testRadiusScaleIsPinned() {
        XCTAssertEqual(Radius.sm, 8)
        XCTAssertEqual(Radius.md, 12)
        XCTAssertEqual(Radius.lg, 16)
    }

    func testTintStepsAreOrderedAndInUnitInterval() {
        XCTAssertGreaterThan(Tint.soft, 0)
        XCTAssertLessThan(Tint.soft, Tint.medium)
        XCTAssertLessThan(Tint.medium, Tint.strong)
        XCTAssertLessThan(Tint.strong, 1.0)
    }

    func testSemanticColorsExist() {
        // We can't reliably compare SwiftUI `Color` instances for equality
        // across platforms, but we can at least confirm that the symbols
        // are reachable and distinct from `.clear`.
        XCTAssertNotEqual(Semantic.success, Color.clear)
        XCTAssertNotEqual(Semantic.warning, Color.clear)
        XCTAssertNotEqual(Semantic.error, Color.clear)
    }
}
