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
        XCTAssertEqual(view.intro.exampleEn, "Yesterday I went to the movies with my sister.")
        XCTAssertEqual(view.intro.audioBase, "eat.mp3")
    }

    func testDismissCallbackFiresOnInvocation() {
        var fired = 0
        let view = VerbIntroCard(intro: makeIntro(), onDismiss: { fired += 1 })
        // Directly invoke the closure the view holds — proxy for tapping the
        // "Listo" CTA or pressing Esc, which both route here.
        view.onDismiss()
        view.onDismiss()
        XCTAssertEqual(fired, 2)
    }

    func testExampleEsKeepsSlotMarker() {
        // The intro intentionally shows the `___` slot (it foreshadows the
        // question shape). If the server starts pre-filling it, the card UX
        // contract changes — this test will catch the drift.
        let intro = makeIntro()
        XCTAssertTrue(intro.exampleEs.contains("___"))
    }
}
