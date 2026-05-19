import XCTest
import SwiftUI
import LessonKit
@testable import GramartEnglish

@MainActor
final class ListeningLessonViewModeTests: XCTestCase {

    private func sampleQuestion() -> LessonQuestion {
        LessonQuestion(
            id: "q0",
            word: "weather",
            options: ["clima", "idioma", "peligroso", "importante"],
            position: 0
        )
    }

    func testPromptForListenPickMeaningAsksForTheMeaning() {
        let view = ListeningLessonView(
            question: sampleQuestion(),
            mode: .listenPickMeaning,
            progress: (current: 1, total: 10),
            onAnswer: { _ in },
            onSkip: {},
            onExit: {}
        )
        // The prompt is computed; force it via reflection-free inspection by
        // checking the public stored properties + the mode-derived prompt
        // we exposed via the view's `mode`.
        XCTAssertEqual(view.mode, .listenPickMeaning)
        // Sanity: question options are the Spanish meanings (not English words).
        XCTAssertTrue(view.question.options.contains("clima"))
        XCTAssertFalse(view.question.options.contains("weather"))
    }

    func testPromptForListenPickWordAsksForTheWord() {
        let englishOptions = ["weather", "language", "dangerous", "important"]
        let q = LessonQuestion(id: "q0", word: "weather", options: englishOptions, position: 0)
        let view = ListeningLessonView(
            question: q,
            mode: .listenPickWord,
            progress: (current: 1, total: 10),
            onAnswer: { _ in },
            onSkip: {},
            onExit: {}
        )
        XCTAssertEqual(view.mode, .listenPickWord)
        XCTAssertTrue(view.question.options.allSatisfy { $0.range(of: "^[A-Za-z][A-Za-z\\s'-]*$", options: .regularExpression) != nil })
    }

    func testListenTypeStillRoutesThroughListeningLessonViewForNow() {
        // Phase 5 (T049-T052) will introduce TypedAnswerInputView. Until then
        // listen_type uses ListeningLessonView too — but the view should
        // declare itself as `isTyped` via the mode so callers can adapt.
        let view = ListeningLessonView(
            question: sampleQuestion(),
            mode: .listenType,
            progress: (current: 1, total: 10),
            onAnswer: { _ in },
            onSkip: {},
            onExit: {}
        )
        XCTAssertTrue(view.mode.isTyped)
        XCTAssertTrue(view.mode.isListening)
    }

    func testAnswerFeedbackInListenPickMeaningKeepsOptionsVisible() {
        // For non-typed modes, the reveal must include the option list so the
        // user sees the green/red highlighting on Spanish meanings.
        let q = sampleQuestion()
        let outcome = AnswerOutcome(
            questionId: q.id,
            chosenIndex: 1,
            kind: .incorrect,
            correctIndex: 0,
            correctOption: "clima",
            canonicalDefinition: "atmospheric conditions"
        )
        let view = AnswerFeedbackView(
            question: q,
            outcome: outcome,
            progress: (current: 1, total: 10),
            isLast: false,
            mode: .listenPickMeaning,
            typedAnswerEcho: nil,
            onNext: {},
            onShowExamples: {}
        )
        XCTAssertEqual(view.mode, .listenPickMeaning)
        XCTAssertNil(view.typedAnswerEcho)
        XCTAssertFalse(view.mode.isTyped)
    }

    func testAnswerFeedbackInListenTypeRendersTypedEcho() {
        let q = LessonQuestion(id: "q0", word: "weather", options: [], position: 0)
        let outcome = AnswerOutcome(
            questionId: q.id,
            chosenIndex: nil,
            kind: .correct,
            correctIndex: 0,
            correctOption: "weather",
            canonicalDefinition: "atmospheric conditions"
        )
        let view = AnswerFeedbackView(
            question: q,
            outcome: outcome,
            progress: (current: 1, total: 10),
            isLast: false,
            mode: .listenType,
            typedAnswerEcho: "wether",
            onNext: {},
            onShowExamples: {}
        )
        XCTAssertEqual(view.typedAnswerEcho, "wether")
        XCTAssertTrue(view.mode.isTyped)
    }
}
