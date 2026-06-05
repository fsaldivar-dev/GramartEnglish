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

    /// v1.6.0 (F004 US1) shipped conjugate_pick_form — the ComingSoonMode
    /// enum is empty for now. When the next coming-soon mode is added
    /// (e.g. F004 US2 `conjugate_type_form`), repopulate this with a real
    /// case to assert the no-op action path. Until then, asserting on the
    /// empty allCases sentinel is the cheapest regression guard.
    func testComingSoonEnumIsEmptyForNow() {
        XCTAssertTrue(ComingSoonMode.allCases.isEmpty,
                      "v1.6.0 shipped every previously coming-soon mode")
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
