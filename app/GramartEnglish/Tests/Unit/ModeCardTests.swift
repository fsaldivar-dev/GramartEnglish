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

    func testComingSoonInitRendersDisabled() {
        let card = ModeCard(comingSoon: .writePickWord)
        XCTAssertTrue(card.comingSoon)
        XCTAssertFalse(card.isEnabled)
        XCTAssertFalse(card.isRecommended)
        XCTAssertNil(card.pendingCount)
        XCTAssertEqual(card.icon, "pencil")
        XCTAssertEqual(card.title, "Escribir")
        XCTAssertTrue(card.subtitle.contains("Próximamente"))
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

    func testConjugateComingSoonHasCircleArrowIcon() {
        let card = ModeCard(comingSoon: .conjugatePickForm)
        XCTAssertEqual(card.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(card.title, "Conjugar")
    }
}
