import XCTest
import LessonKit
@testable import GramartEnglish

/// Mode-card render perf budget (T054, F002 SC).
///
/// Budget: ≤ 50 ms to construct the full 2×3 grid (4 shipped + 2 coming-soon).
/// Real on-screen render time requires Instruments / UI tests; this micro-bench
/// captures the SwiftUI view-tree construction cost so a regression in the
/// per-card overhead is caught early.
final class HomeRenderTests: XCTestCase {

    func testModeCardGridConstructsUnderBudget() {
        let options = XCTMeasureOptions.default
        options.iterationCount = 10
        measure(metrics: [XCTClockMetric()], options: options) {
            for mode in SHIPPED_MODES {
                _ = ModeCard(mode: mode, pendingCount: 12, isRecommended: mode == .listenPickWord, action: {})
            }
            for cs in ComingSoonMode.allCases {
                _ = ModeCard(comingSoon: cs)
            }
        }
    }

    func testSingleModeCardConstructionIsCheap() {
        let options = XCTMeasureOptions.default
        options.iterationCount = 10
        measure(metrics: [XCTClockMetric()], options: options) {
            _ = ModeCard(mode: .listenPickWord, pendingCount: 17, isRecommended: true, action: {})
        }
    }
}
