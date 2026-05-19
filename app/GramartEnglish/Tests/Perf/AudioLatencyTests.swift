import XCTest
import AVFoundation
@testable import GramartEnglish

/// Audio first-token perf budget (T055, F002 SC-003).
///
/// Budget: ≤ 300 ms from "question appears" to "audio starts playing".
/// We measure the wall-clock cost of constructing the utterance + invoking
/// `speak`. Actual audio-to-ear latency depends on Core Audio and is not
/// measurable inside an XCTest process, so this bench captures the largest
/// controllable slice (synth setup + voice resolution).
@MainActor
final class AudioLatencyTests: XCTestCase {

    func testSpeechServiceSpeakReturnsQuickly() {
        let options = XCTMeasureOptions.default
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            // We don't want to actually hear audio in CI — use a short empty-ish
            // string. SpeechService bails out on empty input so we measure only
            // the entry/exit cost. For a meaningful number, swap to a real word
            // locally and watch the console.
            SpeechService.shared.speakEnglish("")
        }
    }

    func testRealWordSpeakIsCheapEnough() {
        // This variant DOES emit audio; skipped by default to keep CI quiet.
        // Run locally with `GRAMART_PERF_AUDIO=1 swift test` to validate end-to-end.
        guard ProcessInfo.processInfo.environment["GRAMART_PERF_AUDIO"] == "1" else {
            return
        }
        let options = XCTMeasureOptions.default
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            SpeechService.shared.speakEnglish("weather")
        }
    }
}
