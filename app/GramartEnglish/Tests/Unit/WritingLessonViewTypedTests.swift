import XCTest
import SwiftUI
import LessonKit
@testable import GramartEnglish

@MainActor
final class WritingLessonViewTypedTests: XCTestCase {

    private func sampleQuestion() -> LessonQuestion {
        LessonQuestion(
            id: "q0",
            word: "weather",
            options: [],
            position: 0,
            prompt: "clima / tiempo"
        )
    }

    func testTypedModeForwardsHintFlagToCallback() {
        var observed: (String, Bool)?
        let view = WritingLessonView(
            question: sampleQuestion(),
            mode: .writeTypeWord,
            progress: (current: 1, total: 10),
            onTypedAnswer: { text, hintUsed in observed = (text, hintUsed) },
            onSkip: {},
            onExit: {}
        )
        // Simulate the inner TypedAnswerInputView calling back with hintUsed=true.
        view.onTypedAnswer("weatherz", true)
        XCTAssertEqual(observed?.0, "weatherz")
        XCTAssertEqual(observed?.1, true)
    }

    func testWriteFillGapsAlsoTreatedAsTyped() {
        // write_fill_gaps lives in LessonMode as a v1.4 placeholder but the
        // typed routing should already work for it — useful so v1.4 can land
        // its masking logic without re-touching the dispatcher.
        let view = WritingLessonView(
            question: sampleQuestion(),
            mode: .writeFillGaps,
            progress: (current: 1, total: 10),
            onSkip: {},
            onExit: {}
        )
        XCTAssertTrue(view.mode.isTyped)
        XCTAssertTrue(view.mode.isWriting)
    }
}
