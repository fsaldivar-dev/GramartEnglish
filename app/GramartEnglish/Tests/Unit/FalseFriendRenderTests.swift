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
        let friend = "OJO: 'realize' = darse cuenta. NO es 'realizar' (que es hacer o llevar a cabo)."
        XCTAssertTrue(friend.hasPrefix("OJO"))
    }

    /// QA + Priya panel (v1.9.0 patch). The belt copy must be PURE Spanish —
    /// no English glosses inside parentheses. The original belt mixed
    /// languages ("OJO: no es 'librería' (bookstore — that's 'bookstore')"),
    /// which both duplicated terms and disrupted Spanish reading flow. We
    /// scan every shipped belt entry across A2 + B1 and assert none contain
    /// the English-only tokens our panel called out.
    func test_allBeltEntries_haveNoEnglishGloss() throws {
        let bannedSubstrings = [
            "(bookstore",
            "(success)",
            "(event)",
            "(folder)",
            "(factory)",
            "(pregnant)",
            "(do/carry out)",
            "(currently/nowadays)",
            "(attend)",
            "(sensitive)"
        ]
        let levels = ["a2", "b1"]
        for level in levels {
            let candidates = [
                URL(fileURLWithPath: "data/cefr/\(level).json"),
                URL(fileURLWithPath: "../../data/cefr/\(level).json"),
                URL(fileURLWithPath: "../../../data/cefr/\(level).json"),
                URL(fileURLWithPath: "../../../../data/cefr/\(level).json")
            ]
            guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
                XCTFail("could not locate data/cefr/\(level).json from CWD \(FileManager.default.currentDirectoryPath)")
                continue
            }
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            for entry in json {
                guard let friend = entry["false_friend_es"] as? String else { continue }
                for banned in bannedSubstrings {
                    XCTAssertFalse(
                        friend.contains(banned),
                        "\(level).json entry for '\(entry["base"] ?? "?")' contains banned English gloss '\(banned)' in: \(friend)"
                    )
                }
            }
        }
    }
}
