import XCTest
@testable import GramartEnglish

/// Cold-launch perf bench. Constitution VIII budget: ≤ 2.0 s on M1 / 16 GB.
/// Uses XCTMetric for repeatable measurement.
final class ColdLaunchTests: XCTestCase {

    func testRootViewBuildsQuickly() {
        // Smoke-bench: instantiating a launching view should be cheap and
        // bounded. Re-run with Instruments for the full app-cold-launch
        // signpost-based measurement.
        let options = XCTMeasureOptions.default
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            _ = LaunchingView()
        }
    }
}
