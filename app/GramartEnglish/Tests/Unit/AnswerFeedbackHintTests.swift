import XCTest
import SwiftUI
import LessonKit
@testable import GramartEnglish

/// F007 (v1.8.0). Pins that `AnswerOutcome.feedbackHint` propagates through
/// the LessonKit model and that `AnswerFeedbackView` renders without
/// throwing both when the hint is present and when it's nil. We can't
/// snapshot the SwiftUI layout from a unit test target, but invoking
/// `.body` exercises the conditional `if let hint = ...` branch end-to-end.
final class AnswerFeedbackHintTests: XCTestCase {

    private func question() -> LessonQuestion {
        LessonQuestion(
            id: "q-1",
            word: "went",
            options: ["went", "go", "gone", "saw"],
            position: 0,
            verbBase: "go",
            targetTense: "simple_past"
        )
    }

    func testOutcomePreservesFeedbackHint() {
        let outcome = AnswerOutcome(
            questionId: "q-1",
            chosenIndex: 3,
            kind: .incorrect,
            correctIndex: 0,
            correctOption: "went",
            canonicalDefinition: "past tense of go",
            feedbackHint: "Casi — \"goed\" es el error típico **de hispanohablantes**, pero \"go\" es irregular. La forma correcta es **went**."
        )
        XCTAssertNotNil(outcome.feedbackHint)
        XCTAssertTrue(outcome.feedbackHint!.contains("irregular"))
        // F008 Item 3 (v1.9.0). Lucía's polish — the hint must name the
        // L1 transfer pattern explicitly.
        XCTAssertTrue(outcome.feedbackHint!.contains("hispanohablantes"))
    }

    func testOutcomeDefaultsToNilFeedbackHint() {
        let outcome = AnswerOutcome(
            questionId: "q-1",
            chosenIndex: 0,
            kind: .correct,
            correctIndex: 0,
            correctOption: "went",
            canonicalDefinition: "past tense of go"
        )
        XCTAssertNil(outcome.feedbackHint)
    }

    func testFeedbackViewRendersWhenHintPresent() {
        let outcome = AnswerOutcome(
            questionId: "q-1",
            chosenIndex: 3,
            kind: .incorrect,
            correctIndex: 0,
            correctOption: "went",
            canonicalDefinition: "past tense of go",
            feedbackHint: "Casi — \"goed\" es el error típico, pero \"go\" es irregular."
        )
        let view = AnswerFeedbackView(
            question: question(),
            outcome: outcome,
            progress: (1, 10),
            isLast: false,
            mode: .conjugatePickForm,
            onNext: {},
            onShowExamples: {}
        )
        XCTAssertNoThrow(_ = view.body)
    }

    func testFeedbackViewRendersWhenHintAbsent() {
        let outcome = AnswerOutcome(
            questionId: "q-1",
            chosenIndex: 0,
            kind: .correct,
            correctIndex: 0,
            correctOption: "went",
            canonicalDefinition: "past tense of go"
        )
        let view = AnswerFeedbackView(
            question: question(),
            outcome: outcome,
            progress: (1, 10),
            isLast: true,
            mode: .conjugatePickForm,
            onNext: {},
            onShowExamples: {}
        )
        XCTAssertNoThrow(_ = view.body)
    }
}
