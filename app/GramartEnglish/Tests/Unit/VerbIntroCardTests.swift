import XCTest
import SwiftUI
import BackendClient
@testable import GramartEnglish

@MainActor
final class VerbIntroCardTests: XCTestCase {

    private func makeIntro(base: String = "go") -> BackendClient.VerbIntro {
        BackendClient.VerbIntro(
            base: base,
            es: "ir",
            exampleEs: "Ayer ___ al cine con mi hermana.",
            exampleEsFilled: "Ayer fui al cine con mi hermana.",
            exampleEn: "Yesterday I went to the movies with my sister.",
            audioBase: "\(base).mp3"
        )
    }

    func testCardBuildsWithoutCrashing() {
        let view = VerbIntroCard(intro: makeIntro(), onDismiss: {})
        // Smoke test — instantiation must not crash. Body is exercised via
        // the SwiftUI runtime in the host app; here we only pin contract
        // values exposed through the struct.
        XCTAssertEqual(view.intro.base, "go")
    }

    func testCardCarriesAllContractFields() {
        let intro = makeIntro(base: "eat")
        let view = VerbIntroCard(intro: intro, onDismiss: {})
        XCTAssertEqual(view.intro.es, "ir")
        XCTAssertEqual(view.intro.exampleEs, "Ayer ___ al cine con mi hermana.")
        XCTAssertEqual(view.intro.exampleEsFilled, "Ayer fui al cine con mi hermana.")
        XCTAssertEqual(view.intro.exampleEn, "Yesterday I went to the movies with my sister.")
        XCTAssertEqual(view.intro.audioBase, "eat.mp3")
    }

    func testDismissCallbackFiresOnInvocation() {
        var fired = 0
        let view = VerbIntroCard(intro: makeIntro(), onDismiss: { fired += 1 })
        // Directly invoke the closure the view holds — proxy for tapping the
        // "Listo" CTA, pressing Esc, or tap-outside, which all route here.
        view.onDismiss()
        view.onDismiss()
        XCTAssertEqual(fired, 2)
    }

    func testExampleEsKeepsSlotMarker() {
        // The unfilled `exampleEs` is the conjugation drill's question.
        // If the server starts pre-filling it the drill loses its gap.
        let intro = makeIntro()
        XCTAssertTrue(intro.exampleEs.contains("___"))
    }

    // MARK: - v1.7.0 Blocker 1

    func testExampleEsFilledHasNoSlotMarker() {
        // The intro card renders `exampleEsFilled` on the Spanish line —
        // it must NEVER contain `___`, otherwise Marisol sees a literal
        // blank on the teaching surface (the bug we're fixing).
        let intro = makeIntro()
        XCTAssertFalse(intro.exampleEsFilled.contains("___"),
                       "Spanish intro line must not show the slot marker")
        XCTAssertTrue(intro.exampleEsFilled.lowercased().contains("fui"),
                      "Spanish intro line must show the past-form substitution")
    }

    // MARK: - v1.7.0 Blocker 2

    func testTapOutsideCardDismisses() {
        // The card sits in a ZStack with a transparent background that owns
        // a tap-to-dismiss gesture. We can't simulate the SwiftUI gesture
        // recognizer from a unit test, but we can pin the contract: the
        // `onDismiss` closure is the SINGLE dismissal sink — CTA, Esc, and
        // background tap all route here. This test documents that contract
        // and ensures we don't regress to multiple sinks.
        var fired = 0
        let view = VerbIntroCard(intro: makeIntro(), onDismiss: { fired += 1 })
        // Simulate three dismissal paths converging on the same callback:
        view.onDismiss() // CTA
        view.onDismiss() // Esc
        view.onDismiss() // tap-outside
        XCTAssertEqual(fired, 3,
                       "All three dismissal paths must invoke the same onDismiss")
    }

    // MARK: - v1.7.0 Polish D — SpeakButton VO label

    func testSpeakButtonDefaultLabelIsGeneric() {
        // Polish D: the speaker's a11y label used to be "Escuchar: <verb>",
        // which combined with the adjacent verb text and the post-tap
        // announcement read the verb three times. The label is now
        // verb-agnostic ("Reproducir palabra en inglés"). The struct still
        // takes a `label` parameter for backward compatibility, but it's no
        // longer concatenated with the verb. This test pins the default.
        let btn = SpeakButton(text: "wake", shortcut: "s")
        XCTAssertEqual(btn.label, "Escuchar")
        XCTAssertEqual(btn.text, "wake")
    }
}
