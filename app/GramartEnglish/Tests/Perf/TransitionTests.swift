import XCTest
@testable import GramartEnglish

/// Screen-transition perf placeholder. Constitution VIII budget: ≤ 150 ms.
///
/// Real measurement requires instrumented signposts captured by Instruments
/// or a UI-test harness; this file documents the budget and gives a baseline
/// micro-bench for the lightest cost (constructing the next view).
final class TransitionTests: XCTestCase {

    func testLaunchingViewIsCheapToConstruct() {
        let options = XCTMeasureOptions.default
        options.iterationCount = 10
        measure(metrics: [XCTClockMetric()], options: options) {
            _ = LaunchingView()
            _ = ScaffoldFailedView(message: "bench")
        }
    }
}
