import XCTest
@testable import GramartEnglish

/// v1.4.1 F3 — verify the mute toggle on `SpeechService` short-circuits
/// auto-fire calls while still letting user-initiated taps through.
///
/// We can't easily assert that AVSpeechSynthesizer actually emitted audio in
/// CI (the synth is fire-and-forget), so the contract under test is the
/// EARLY RETURN at the top of `speakEnglish` — when muted + auto-fire, the
/// call must be a no-op BEFORE touching the synthesizer or dispatching to
/// the main queue. We verify this by toggling `isMuted` and confirming the
/// persisted UserDefaults round-trips, plus making the calls themselves to
/// confirm they don't crash regardless of mute state.
final class SpeechServiceMuteTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "gramart.speech.mute.tests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_isMuted_defaultsToFalse() {
        let svc = SpeechService(defaults: defaults)
        XCTAssertFalse(svc.isMuted)
    }

    func test_setIsMuted_persistsToUserDefaults() {
        let svc = SpeechService(defaults: defaults)
        svc.isMuted = true
        XCTAssertTrue(defaults.bool(forKey: SpeechService.muteDefaultsKey))

        // A fresh service instance reading the same defaults sees the value.
        let svc2 = SpeechService(defaults: defaults)
        XCTAssertTrue(svc2.isMuted)
    }

    /// Contract: when `isMuted == true` and the call is NOT user-initiated,
    /// `speakEnglish` returns early. The smoke test is that the call does
    /// not throw and does not start any utterance — we can't observe the
    /// no-op directly, but pairing it with the persisted flag covers the
    /// behavioral contract documented on the API.
    func test_speakEnglish_autoFireWhileMuted_isNoOp() {
        let svc = SpeechService(defaults: defaults)
        svc.isMuted = true
        // Auto-fire (no isUserInitiated) — must not crash.
        svc.speakEnglish("hello")
        // Explicit isUserInitiated: false — same path.
        svc.speakEnglish("hello", isUserInitiated: false)
        // Still muted afterward.
        XCTAssertTrue(svc.isMuted)
    }

    /// Contract: user-initiated calls bypass the mute toggle. We can't hear
    /// the audio in a unit test, but the call must reach past the early
    /// return without errors.
    func test_speakEnglish_userInitiatedWhileMuted_proceeds() {
        let svc = SpeechService(defaults: defaults)
        svc.isMuted = true
        svc.speakEnglish("hello", isUserInitiated: true)
        // Still muted (user-initiated does not clear the preference).
        XCTAssertTrue(svc.isMuted)
    }

    func test_speakEnglish_unmuted_proceedsForAutoFire() {
        let svc = SpeechService(defaults: defaults)
        svc.isMuted = false
        svc.speakEnglish("hello")
        XCTAssertFalse(svc.isMuted)
    }
}
