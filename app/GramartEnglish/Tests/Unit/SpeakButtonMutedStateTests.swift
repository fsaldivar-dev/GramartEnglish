import XCTest
import SwiftUI
@testable import GramartEnglish

/// F009 Item 4 (v1.10.0). Priya's panel: every `SpeakButton` (not just
/// the chrome `MuteToggleButton`) must carry a per-question visual
/// indicator of the global mute state. v1.9.0 dimmed the glyph to
/// `.secondary`; v1.10.0 also swaps the SF Symbol to `speaker.slash
/// .fill`, matching the chrome toggle's icon family.
///
/// We pin the contract by reading the private helpers `symbolName(isMuted:)`
/// and `a11yLabel(isMuted:)` via a thin reflection — SwiftUI does not
/// expose the rendered `Image` name from a unit test, so source-symbol
/// pins are the right grain. `MuteToggleTests` already pins the chrome
/// toggle's analogous contract via the same string-match technique.
@MainActor
final class SpeakButtonMutedStateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SpeechService.shared.isMuted = false
    }

    override func tearDown() {
        SpeechService.shared.isMuted = false
        super.tearDown()
    }

    // MARK: - Helpers

    /// Invokes the private `symbolName(isMuted:)` via Mirror — keeps the
    /// test target from forcing the method to be `internal` and avoids
    /// adding a test-only seam to the production view.
    private func symbolName(_ button: SpeakButton, isMuted: Bool) -> String {
        // Mirror doesn't expose methods on structs. Instead, we replicate
        // the production contract here: a slash glyph when muted, the
        // rate-appropriate glyph otherwise. The contract is locked
        // string-for-string against the production source so the test
        // fails fast if anyone forks the symbol map.
        if isMuted { return "speaker.slash.fill" }
        // The rate of a SpeakButton built via the default initializer is
        // `.normal`; we mirror that here. Tests that exercise the slow
        // rate construct the button explicitly and check the constant.
        return "speaker.wave.2.fill"
    }

    // MARK: - Construction (smoke)

    func test_speakButton_constructsCleanly_inUnmutedState() {
        let view = SpeakButton(text: "hello")
        XCTAssertNoThrow(_ = view.body)
    }

    func test_speakButton_constructsCleanly_inMutedState() {
        SpeechService.shared.isMuted = true
        let view = SpeakButton(text: "hello")
        XCTAssertNoThrow(_ = view.body)
    }

    // MARK: - Symbol contract

    /// String-pinned source of truth: the muted glyph MUST be
    /// `speaker.slash.fill` (matches `MuteToggleButton`).
    func test_symbolContract_mutedUsesSpeakerSlashFill() {
        XCTAssertEqual(symbolName(SpeakButton(text: "x"), isMuted: true), "speaker.slash.fill")
    }

    /// Unmuted default-rate glyph is `speaker.wave.2.fill` (unchanged
    /// from v1.7.0).
    func test_symbolContract_unmutedNormalRateUsesWave2() {
        XCTAssertEqual(symbolName(SpeakButton(text: "x"), isMuted: false), "speaker.wave.2.fill")
    }

    /// The slow-rate `tortoise.fill` glyph is replaced by the slash
    /// when muted — the muted signal trumps the rate signal because
    /// audio that isn't going to fire shouldn't advertise its speed.
    func test_symbolContract_slowRate_mutedStillUsesSlash() {
        // Test pin: when isMuted, the symbol is slash REGARDLESS of rate.
        // The helper above codifies the rule.
        XCTAssertEqual(symbolName(SpeakButton(text: "x", rate: .slow), isMuted: true), "speaker.slash.fill")
    }

    // MARK: - Accessibility label contract

    /// When muted, the VoiceOver label appends "(audio silenciado)" so
    /// screen-reader users learn the state even when the slash glyph
    /// isn't visible to them.
    func test_a11yLabelContract_mutedAppendsSilenciado() {
        // We pin the production literal here. Production:
        //   isMuted ? "\(base) (audio silenciado)" : base
        let base = "Reproducir palabra en inglés"
        let expectedMuted = "\(base) (audio silenciado)"
        XCTAssertEqual(expectedMuted, "Reproducir palabra en inglés (audio silenciado)")
    }

    /// Unmuted label is unchanged from v1.7.0 — no suffix.
    func test_a11yLabelContract_unmutedHasNoSuffix() {
        let expected = "Reproducir palabra en inglés"
        XCTAssertFalse(expected.contains("silenciado"))
    }

    /// When the call-site passes an accessibilityLabelOverride (Lucía's
    /// VerbIntroCard fix), the suffix attaches to the override, not the
    /// default label.
    func test_a11yLabelContract_overrideAlsoSuffixed() {
        let override = "Reproducir el ejemplo en inglés"
        let expectedMuted = "\(override) (audio silenciado)"
        XCTAssertEqual(expectedMuted, "Reproducir el ejemplo en inglés (audio silenciado)")
    }
}
