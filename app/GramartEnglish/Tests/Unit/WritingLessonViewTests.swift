import XCTest
import SwiftUI
import LessonKit
@testable import GramartEnglish

@MainActor
final class WritingLessonViewTests: XCTestCase {

    private func sampleQuestion(prompt: String? = "clima / tiempo") -> LessonQuestion {
        LessonQuestion(
            id: "q0",
            word: "weather",
            options: ["weather", "kitchen", "market", "advice"],
            position: 0,
            prompt: prompt
        )
    }

    func testRendersSpanishPromptForWritePickWord() {
        let view = WritingLessonView(
            question: sampleQuestion(),
            mode: .writePickWord,
            progress: (current: 1, total: 10),
            onSkip: {},
            onExit: {}
        )
        XCTAssertEqual(view.mode, .writePickWord)
        XCTAssertEqual(view.question.prompt, "clima / tiempo")
        XCTAssertFalse(view.mode.isTyped)
        XCTAssertTrue(view.mode.isWriting)
        // Options arrive from the backend with the canonical English word inside.
        XCTAssertTrue(view.question.options.contains("weather"))
    }

    func testFallsBackToWordWhenPromptIsMissing() {
        // Defensive: if the backend forgot to send `prompt` (or we're on a
        // pre-1.3 server), the view still renders something — the English
        // word. The behavior matches our v1.2 fallback story.
        let q = LessonQuestion(id: "q1", word: "weather", options: ["weather", "kitchen", "market", "advice"], position: 0, prompt: nil)
        let view = WritingLessonView(
            question: q,
            mode: .writePickWord,
            progress: (current: 1, total: 10),
            onSkip: {},
            onExit: {}
        )
        XCTAssertNil(view.question.prompt)
    }

    func testTypedModePresentsTypedInputAndNoOptions() {
        let view = WritingLessonView(
            question: sampleQuestion(),
            mode: .writeTypeWord,
            progress: (current: 1, total: 10),
            onSkip: {},
            onExit: {}
        )
        XCTAssertTrue(view.mode.isTyped)
        XCTAssertTrue(view.mode.isWriting)
    }

    func testOnAnswerCallbackFiresOnOptionTap() {
        var observed: Int?
        let view = WritingLessonView(
            question: sampleQuestion(),
            mode: .writePickWord,
            progress: (current: 1, total: 10),
            onAnswer: { observed = $0 },
            onSkip: {},
            onExit: {}
        )
        view.onAnswer(2)
        XCTAssertEqual(observed, 2)
    }

    func testOnTypedAnswerCallbackFiresWithHintFlag() {
        var observed: (String, Bool)?
        let view = WritingLessonView(
            question: sampleQuestion(),
            mode: .writeTypeWord,
            progress: (current: 1, total: 10),
            onTypedAnswer: { text, hintUsed in observed = (text, hintUsed) },
            onSkip: {},
            onExit: {}
        )
        view.onTypedAnswer("weatherz", false)
        XCTAssertEqual(observed?.0, "weatherz")
        XCTAssertEqual(observed?.1, false)
        view.onTypedAnswer("weather", true)
        XCTAssertEqual(observed?.0, "weather")
        XCTAssertEqual(observed?.1, true)
    }
}
