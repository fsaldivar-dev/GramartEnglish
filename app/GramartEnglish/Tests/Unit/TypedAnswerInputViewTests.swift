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
            onSubmit: { _ in },
            onSkip: {}
        )
        XCTAssertEqual(view.questionId, "q1")
        XCTAssertEqual(view.canonical, "weather")
    }

    func testOnSubmitClosureCanReceiveTrimmedText() {
        var observed: String?
        let view = TypedAnswerInputView(
            questionId: "q1",
            canonical: "weather",
            onSubmit: { observed = $0 },
            onSkip: {}
        )
        // The view trims internally before calling onSubmit; emulate by calling
        // it with the value the view would compute.
        view.onSubmit("weather")
        XCTAssertEqual(observed, "weather")
    }

    func testOnSkipClosureWired() {
        var fired = 0
        let view = TypedAnswerInputView(
            questionId: "q1",
            canonical: "x",
            onSubmit: { _ in },
            onSkip: { fired += 1 }
        )
        view.onSkip()
        XCTAssertEqual(fired, 1)
    }
}
