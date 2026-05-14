import XCTest
import LessonKit
@testable import GramartEnglish

@MainActor
final class ModeCardComingSoonTests: XCTestCase {

    /// A coming-soon card must be both visually disabled and behaviorally inert.
    func testAllComingSoonModesProduceDisabledCards() {
        for mode in ComingSoonMode.allCases {
            let card = ModeCard(comingSoon: mode)
            XCTAssertTrue(card.comingSoon, "\(mode.rawValue) should be marked comingSoon")
            XCTAssertFalse(card.isEnabled, "\(mode.rawValue) should be disabled")
            XCTAssertNil(card.pendingCount, "\(mode.rawValue) should not show pending count")
            XCTAssertTrue(card.subtitle.contains("Próximamente"), "subtitle should mention Próximamente")
        }
    }

    /// The default `comingSoon` action is a no-op so accidentally invoking it
    /// won't crash or call into RootView's mode-tap handler.
    func testDefaultComingSoonActionIsNoOp() {
        let card = ModeCard(comingSoon: .writePickWord)
        // Should not crash; nothing to assert beyond "did not throw".
        card.action()
    }

    /// Recommended-tag never decorates a coming-soon card — the recommender
    /// itself filters them out, but the view-level invariant matters too.
    func testComingSoonCardsAreNeverRecommended() {
        for mode in ComingSoonMode.allCases {
            let card = ModeCard(comingSoon: mode)
            XCTAssertFalse(card.isRecommended, "\(mode.rawValue) must not display the Recomendado tag")
        }
    }
}
