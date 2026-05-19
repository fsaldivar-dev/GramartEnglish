import XCTest
@testable import LessonKit

final class LessonKitTests: XCTestCase {

    private func sample() -> LessonState {
        let questions = (0..<3).map { idx in
            LessonQuestion(id: "q\(idx)", word: "w\(idx)", options: ["A", "B", "C", "D"], position: idx)
        }
        return LessonState(lessonId: "L1", questions: questions)
    }

    func testInitialState() {
        let state = sample()
        XCTAssertEqual(state.currentIndex, 0)
        XCTAssertEqual(state.outcomes.count, 0)
        XCTAssertEqual(state.progress.current, 1)
        XCTAssertEqual(state.progress.total, 3)
        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.currentQuestion?.id, "q0")
    }

    func testRecordOutcomeAndAdvance() {
        var state = sample()
        state.recordOutcome(.init(questionId: "q0", chosenIndex: 1, kind: .correct, correctIndex: 1, correctOption: "A", canonicalDefinition: "d0"))
        state.advance()
        XCTAssertEqual(state.currentIndex, 1)
        XCTAssertEqual(state.outcomes.count, 1)
        XCTAssertEqual(state.score, 1)
        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.currentQuestion?.id, "q1")
    }

    func testCompletionAndScore() {
        var state = sample()
        for idx in 0..<3 {
            state.recordOutcome(.init(
                questionId: "q\(idx)",
                chosenIndex: 0,
                kind: idx % 2 == 0 ? .correct : .incorrect,
                correctIndex: 0,
                correctOption: "A",
                canonicalDefinition: "d\(idx)"
            ))
            state.advance()
        }
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.score, 2) // q0 and q2 were "correct"
        XCTAssertNil(state.currentQuestion)
    }

    func testSkipDoesNotIncreaseScore() {
        var state = sample()
        state.recordOutcome(.init(questionId: "q0", chosenIndex: nil, kind: .skipped, correctIndex: 1, correctOption: "B", canonicalDefinition: "d0"))
        state.advance()
        XCTAssertEqual(state.score, 0)
        XCTAssertEqual(state.outcomes.count, 1)
    }

    func testAdvancePastEndIsBounded() {
        var state = sample()
        for _ in 0..<10 { state.advance() }
        XCTAssertEqual(state.currentIndex, 3)
        XCTAssertNil(state.currentQuestion)
    }
}
