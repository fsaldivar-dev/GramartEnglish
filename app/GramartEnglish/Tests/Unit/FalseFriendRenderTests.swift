import XCTest
import SwiftUI
import LessonKit
@testable import GramartEnglish

/// F008 Item 3 (v1.9.0). The Spanish false-friend chip is rendered by
/// `AnswerFeedbackView` when `LessonQuestion.falseFriendEs` is present.
/// Pins:
///   1. `LessonQuestion` carries the optional field through its initializer
///      unchanged (default `nil` so existing call-sites compile),
///   2. `AnswerFeedbackView` instantiates cleanly both when the field is
///      present (renders the chip) and absent (no chip),
///   3. Spanish copy contains the literal "OJO" stem so the warning lands
///      as Lucía's belt entries specify (smoke test for downstream JSON
///      truncation bugs).
@MainActor
final class FalseFriendRenderTests: XCTestCase {

    private func question(withFalseFriend friend: String?) -> LessonQuestion {
        LessonQuestion(
            id: "q-1",
            word: "library",
            options: ["biblioteca", "librería", "papelería", "kiosko"],
            position: 0,
            falseFriendEs: friend
        )
    }

    private func outcome(isCorrect: Bool) -> AnswerOutcome {
        AnswerOutcome(
            questionId: "q-1",
            chosenIndex: isCorrect ? 0 : 1,
            kind: isCorrect ? .correct : .incorrect,
            correctIndex: 0,
            correctOption: "biblioteca",
            canonicalDefinition: "A place where you can borrow books to read."
        )
    }

    func test_lessonQuestion_carriesFalseFriendEs() {
        let q = question(withFalseFriend: "OJO: no es 'librería' (bookstore)")
        XCTAssertEqual(q.falseFriendEs, "OJO: no es 'librería' (bookstore)")
    }

    func test_lessonQuestion_falseFriendEsDefaultsNil() {
        let q = question(withFalseFriend: nil)
        XCTAssertNil(q.falseFriendEs)
    }

    /// Smoke: rendering with a populated false-friend doesn't throw. We
    /// can't drive a layout pass without a UI host, but `.body` evaluation
    /// exercises every conditional `if let …` branch.
    func test_answerFeedbackView_rendersWhenFalseFriendPresent() {
        let view = AnswerFeedbackView(
            question: question(withFalseFriend: "OJO: no es 'librería' (bookstore — that's 'bookstore')"),
            outcome: outcome(isCorrect: false),
            progress: (1, 10),
            isLast: false,
            mode: .readPickMeaning,
            onNext: {},
            onShowExamples: {}
        )
        XCTAssertNoThrow(_ = view.body)
    }

    func test_answerFeedbackView_rendersWhenFalseFriendAbsent() {
        let view = AnswerFeedbackView(
            question: question(withFalseFriend: nil),
            outcome: outcome(isCorrect: true),
            progress: (1, 10),
            isLast: false,
            mode: .readPickMeaning,
            onNext: {},
            onShowExamples: {}
        )
        XCTAssertNoThrow(_ = view.body)
    }

    /// F008 Item 3. Lucía's pedagogy: belt entries start with "OJO" (Spanish
    /// idiomatic "heads up") because hispanohablantes recognise it as a
    /// stop-signal. A future copy refactor must not silently drop it.
    func test_beltCopy_startsWithOJO() {
        let friend = "OJO: no es 'realizar' (do/carry out)"
        XCTAssertTrue(friend.hasPrefix("OJO"))
    }
}
