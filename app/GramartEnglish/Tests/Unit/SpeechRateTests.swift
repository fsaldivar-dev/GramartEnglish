import XCTest
@testable import GramartEnglish

/// F007 (v1.8.0). Pins the concrete numeric values backing `SpeechRate.normal`
/// and `SpeechRate.slow`. Lucía calibrated these against her own pronunciation
/// drills; changing them is a content decision, not an implementation detail.
/// If you need to nudge a rate, update the constants below in the same PR so
/// reviewers see the trade-off explicitly.
final class SpeechRateTests: XCTestCase {

    func testNormalRateIsPinned() {
        // 0.42 ≈ Apple Translate's per-word default. Same value the historic
        // `speakEnglish` used before F007 introduced the enum wrapper, so the
        // user-perceived "normal" speed is unchanged.
        XCTAssertEqual(SpeechRate.normal.value, 0.42, accuracy: 0.0001)
    }

    func testSlowRateIsPinned() {
        // 0.35 ≈ MinimumSpeechRate * 0.4 + DefaultSpeechRate * 0.6
        // calibrated to be unambiguously slower than `.normal` (delta ≥ 0.05)
        // without crossing into the "robot syllabification" zone < 0.30 where
        // intonation collapses.
        XCTAssertEqual(SpeechRate.slow.value, 0.35, accuracy: 0.0001)
    }

    func testSlowIsActuallySlowerThanNormal() {
        XCTAssertLessThan(SpeechRate.slow.value, SpeechRate.normal.value)
        // Be explicit about the audible gap so a future tweak that crushes
        // them together (e.g. normal=0.40, slow=0.38) fails fast.
        let delta = SpeechRate.normal.value - SpeechRate.slow.value
        XCTAssertGreaterThanOrEqual(delta, 0.05, "Slow rate must be ≥0.05 below normal to be audibly distinct")
    }
}
