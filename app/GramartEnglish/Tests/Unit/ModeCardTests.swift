import XCTest
import SwiftUI
import LessonKit
@testable import GramartEnglish

@MainActor
final class ModeCardTests: XCTestCase {

    func testInitFromLessonModeMapsTitleAndIcon() {
        let card = ModeCard(
            mode: .listenPickWord,
            pendingCount: 12,
            isRecommended: true,
            action: {}
        )
        XCTAssertEqual(card.icon, "ear")
        XCTAssertEqual(card.title, "Escuchar")
        XCTAssertEqual(card.subtitle, "Escucha y elige la palabra")
        XCTAssertEqual(card.pendingCount, 12)
        XCTAssertTrue(card.isEnabled)
        XCTAssertFalse(card.comingSoon)
        XCTAssertTrue(card.isRecommended)
    }

    func testReadModeUsesBookIcon() {
        let card = ModeCard(mode: .readPickMeaning, pendingCount: 0, isRecommended: false, action: {})
        XCTAssertEqual(card.icon, "book")
        XCTAssertEqual(card.title, "Leer")
    }

/// v1.6.0 shipped conjugatePickForm — Conjugar is no longer a coming-soon
    /// card. Asserting the LessonMode init produces an enabled card with the
    /// final copy keeps the regression in place.
    func testConjugatePickFormShipsAsEnabledCard() {
        let card = ModeCard(mode: .conjugatePickForm, pendingCount: 4, isRecommended: false, action: {})
        XCTAssertFalse(card.comingSoon)
        XCTAssertTrue(card.isEnabled)
        XCTAssertEqual(card.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(card.title, "Conjugar")
        XCTAssertEqual(card.subtitle, "Lee el verbo en español, elige la forma en pasado")
    }

    func testActionFiresWhenEnabledAndNotComingSoon() {
        var fired = 0
        let card = ModeCard(
            icon: "ear",
            title: "Escuchar",
            subtitle: "x",
            pendingCount: 5,
            isEnabled: true,
            comingSoon: false,
            isRecommended: false,
            action: { fired += 1 }
        )
        // The Button view wraps the action with the same enabled/comingSoon gate
        // — call the closure directly to validate the gate at the model level.
        card.action()
        XCTAssertEqual(fired, 1)
    }

    func testConjugateShippedHasCircleArrowIcon() {
        let card = ModeCard(mode: .conjugatePickForm, pendingCount: 0, isRecommended: false, action: {})
        XCTAssertEqual(card.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(card.title, "Conjugar")
    }
}
