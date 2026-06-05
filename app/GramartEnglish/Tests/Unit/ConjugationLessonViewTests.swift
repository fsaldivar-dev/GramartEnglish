import XCTest
import LessonKit
@testable import GramartEnglish

@MainActor
final class ConjugationLessonViewTests: XCTestCase {

    private func makeQuestion(
        verbBase: String = "go",
        spanishInfinitive: String = "ir",
        options: [String] = ["went", "goed", "go", "gone"],
        exampleEs: String? = "Ayer ___ al cine con mi hermana.",
        exampleEn: String? = "Yesterday I went to the movies with my sister."
    ) -> LessonQuestion {
        LessonQuestion(
            id: "q1",
            word: verbBase,
            options: options,
            position: 0,
            prompt: "Pasado simple de **\(spanishInfinitive)**",
            maskedWord: nil,
            verbBase: verbBase,
            targetTense: "simple_past",
            exampleEs: exampleEs,
            exampleEn: exampleEn
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

    // MARK: - v1.6.0 patch (Blocker 2): example sentence carries through

    func testQuestionCarriesExampleSentencesForConjugatePickForm() {
        let q = makeQuestion(
            verbBase: "eat",
            spanishInfinitive: "comer",
            options: ["ate", "eated", "eat", "eaten"],
            exampleEs: "Ayer ___ tacos al pastor en la esquina.",
            exampleEn: "Yesterday I ate al pastor tacos on the corner."
        )
        XCTAssertEqual(q.exampleEs, "Ayer ___ tacos al pastor en la esquina.")
        XCTAssertNotNil(q.exampleEn)
        // The Spanish example anchors tense with a temporal marker and
        // uses `___` for the verb slot — that anchor is what disambiguates
        // preterite/imperfect for the learner.
        XCTAssertTrue(q.exampleEs!.contains("___"))
    }

    func testExampleSentenceRendersOnHeroWhenProvided() {
        // Smoke-test only: building the view with example_es present must
        // not crash (the secondary-style sentence is rendered by the
        // optional branch in `conjugationPromptHero`). For pixel-level
        // pinning of the rendered string we'd need ViewInspector or
        // snapshot tests, which are out of scope for this patch.
        let withExample = makeQuestion()
        XCTAssertNotNil(withExample.exampleEs)
        let view = ConjugationLessonView(
            question: withExample,
            progress: (current: 1, total: 10),
            onAnswer: { _ in }, onSkip: { }, onExit: { }
        )
        XCTAssertEqual(view.question.exampleEs, withExample.exampleEs)

        // And it must also build cleanly when the example is absent (e.g.
        // for non-conjugate modes that don't populate it).
        let withoutExample = makeQuestion(exampleEs: nil, exampleEn: nil)
        let view2 = ConjugationLessonView(
            question: withoutExample,
            progress: (current: 1, total: 10),
            onAnswer: { _ in }, onSkip: { }, onExit: { }
        )
        XCTAssertNil(view2.question.exampleEs)
    }
}
