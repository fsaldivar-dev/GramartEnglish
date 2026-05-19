import XCTest
import SwiftUI
@testable import GramartEnglish

@MainActor
final class TypedAnswerInputViewTests: XCTestCase {

    /// The view publishes its core configuration via stored properties.
    /// We exercise the construction path + closure wiring here; full keyboard /
    /// focus behavior is covered by manual QA on macOS.
    func testStoresQuestionAndCanonical() {
        let view = TypedAnswerInputView(
            questionId: "q1",
            canonical: "weather",
            onSubmit: { _, _ in },
            onSkip: {}
        )
        XCTAssertEqual(view.questionId, "q1")
        XCTAssertEqual(view.canonical, "weather")
    }

    func testOnSubmitClosureCanReceiveTrimmedTextAndHintFlag() {
        var observed: (String, Bool)?
        let view = TypedAnswerInputView(
            questionId: "q1",
            canonical: "weather",
            onSubmit: { text, hintUsed in observed = (text, hintUsed) },
            onSkip: {}
        )
        // Emulate what the view's submit() helper would compute.
        view.onSubmit("weather", false)
        XCTAssertEqual(observed?.0, "weather")
        XCTAssertEqual(observed?.1, false)
        // And with hintUsed=true (FR-009 path).
        view.onSubmit("weatherz", true)
        XCTAssertEqual(observed?.0, "weatherz")
        XCTAssertEqual(observed?.1, true)
    }

    func testOnSkipClosureWired() {
        var fired = 0
        let view = TypedAnswerInputView(
            questionId: "q1",
            canonical: "x",
            onSubmit: { _, _ in },
            onSkip: { fired += 1 }
        )
        view.onSkip()
        XCTAssertEqual(fired, 1)
    }
}
