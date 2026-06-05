import XCTest
import LessonKit
@testable import GramartEnglish

@MainActor
final class ConjugationLessonViewTests: XCTestCase {

    private func makeQuestion(
        verbBase: String = "go",
        spanishInfinitive: String = "ir",
        options: [String] = ["went", "goed", "go", "gone"]
    ) -> LessonQuestion {
        LessonQuestion(
            id: "q1",
            word: verbBase,
            options: options,
            position: 0,
            prompt: "Pasado simple de **\(spanishInfinitive)**",
            maskedWord: nil,
            verbBase: verbBase,
            targetTense: "simple_past"
        )
    }

    // MARK: - Spanish prompt parsing

    func testSpanishInfinitiveParserExtractsTokenBetweenMarkers() {
        XCTAssertEqual(ConjugationLessonView.spanishInfinitive(from: "Pasado simple de **ir**"), "ir")
        XCTAssertEqual(ConjugationLessonView.spanishInfinitive(from: "Pasado simple de **comer**"), "comer")
        // Multi-word Spanish infinitives (e.g. "pedir prestado") survive intact.
        XCTAssertEqual(
            ConjugationLessonView.spanishInfinitive(from: "Pasado simple de **pedir prestado**"),
            "pedir prestado"
        )
    }

    func testSpanishInfinitiveParserReturnsNilForMissingOrMalformedPrompts() {
        XCTAssertNil(ConjugationLessonView.spanishInfinitive(from: nil))
        XCTAssertNil(ConjugationLessonView.spanishInfinitive(from: ""))
        XCTAssertNil(ConjugationLessonView.spanishInfinitive(from: "Pasado simple de ir"))
        XCTAssertNil(ConjugationLessonView.spanishInfinitive(from: "Pasado simple de **"))
    }

    // MARK: - Question DTO contract

    func testQuestionCarriesVerbBaseAndTargetTense() {
        let q = makeQuestion()
        XCTAssertEqual(q.verbBase, "go")
        XCTAssertEqual(q.targetTense, "simple_past")
        XCTAssertNil(q.maskedWord) // conjugation is option-based, never masked
    }

    func testPromptStringIsPinnedToFrenchSpec() {
        // The Spanish prompt copy is the contract — PO+TL locked
        // "Pasado simple de **<es>**" verbatim.
        let q = makeQuestion(spanishInfinitive: "ir")
        XCTAssertEqual(q.prompt, "Pasado simple de **ir**")
    }

    // MARK: - View construction (smoke)

    func testViewBuildsWithFourOptions() {
        let q = makeQuestion()
        // SwiftUI views are values — instantiation must not crash with
        // realistic input. The body's accessibility hooks are exercised by
        // the static parser tests above; here we just verify no nil/empty
        // shortcuts trip up the closure capture.
        let view = ConjugationLessonView(
            question: q,
            progress: (current: 1, total: 10),
            onAnswer: { _ in },
            onSkip: { },
            onExit: { }
        )
        XCTAssertEqual(view.question.options.count, 4)
    }
}
