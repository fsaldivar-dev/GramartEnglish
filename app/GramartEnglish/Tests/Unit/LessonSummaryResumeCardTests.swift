import XCTest
import SwiftUI
import BackendClient
import LessonKit
@testable import GramartEnglish

/// F010 Item 3 (v1.11.0). Priya's P1 — when the summary screen renders
/// and the local snapshot points at a DIFFERENT in-flight lesson, the
/// `ResumeLessonCard` must surface above the existing CTAs. When the
/// snapshot matches (we just finished what was saved) or is nil, the
/// card stays hidden.
///
/// The view's `shouldShowResumeCard` predicate is exposed publicly so
/// these assertions don't have to crawl the SwiftUI body graph.
@MainActor
final class LessonSummaryResumeCardTests: XCTestCase {

    private static let kSummaryLessonId = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
    private static let kOtherLessonId   = "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB"

    private func sampleSummary(
        lessonId: String = LessonSummaryResumeCardTests.kSummaryLessonId
    ) -> BackendClient.LessonSummaryResponse {
        let json = """
        {
          "lessonId": "\(lessonId)",
          "score": 7,
          "skipped": 1,
          "wrong": 2,
          "total": 10,
          "missedWords": []
        }
        """
        return try! JSONDecoder().decode(
            BackendClient.LessonSummaryResponse.self,
            from: Data(json.utf8)
        )
    }

    private func snapshot(lessonId: String) -> LessonStateSnapshot {
        LessonStateSnapshot(
            lessonId: lessonId,
            mode: LessonMode.readPickMeaning.rawValue,
            level: "A2",
            phase: .answering,
            currentQuestionIndex: 3,
            answeredCount: 3
        )
    }

    private func makeView(snapshot: LessonStateSnapshot?) -> LessonSummaryView {
        LessonSummaryView(
            summary: sampleSummary(),
            mode: .readPickMeaning,
            perModeMastered: nil,
            resumableSnapshot: snapshot,
            onStartAnother: {},
            onBackHome: {},
            onResumeLesson: {}
        )
    }

    func test_resumeCard_hidden_whenSnapshotIsNil() {
        let view = makeView(snapshot: nil)
        XCTAssertFalse(view.shouldShowResumeCard,
            "No snapshot → no resume CTA")
    }

    func test_resumeCard_hidden_whenSnapshotMatchesSummary() {
        // The user just finished the lesson the snapshot tracked — the
        // store will be cleared on the next phase tick. We must NOT
        // suggest they resume their own just-completed run.
        let snap = snapshot(lessonId: Self.kSummaryLessonId)
        let view = makeView(snapshot: snap)
        XCTAssertFalse(view.shouldShowResumeCard,
            "Snapshot lessonId == summary.lessonId → card hidden")
    }

    func test_resumeCard_shown_whenSnapshotIsForDifferentLesson() {
        let snap = snapshot(lessonId: Self.kOtherLessonId)
        let view = makeView(snapshot: snap)
        XCTAssertTrue(view.shouldShowResumeCard,
            "Snapshot points at a different lesson → surface the CTA")
        // Body should still build without throwing — guard against a
        // nil-unwrap in the inserted card.
        XCTAssertNoThrow(_ = view.body)
    }

    func test_onResumeLesson_callback_isWiredIndependently() {
        var resumeCount = 0
        var startedAnotherCount = 0
        var backHomeCount = 0
        let snap = snapshot(lessonId: Self.kOtherLessonId)
        let view = LessonSummaryView(
            summary: sampleSummary(),
            mode: .readPickMeaning,
            perModeMastered: nil,
            resumableSnapshot: snap,
            onStartAnother: { startedAnotherCount += 1 },
            onBackHome: { backHomeCount += 1 },
            onResumeLesson: { resumeCount += 1 }
        )
        XCTAssertNoThrow(_ = view.body)
        // Pre-state — no callback should have fired from rendering alone.
        XCTAssertEqual(resumeCount, 0)
        XCTAssertEqual(startedAnotherCount, 0)
        XCTAssertEqual(backHomeCount, 0)
        // Invoking onResumeLesson must not collapse to the other CTAs.
        view.onResumeLesson()
        XCTAssertEqual(resumeCount, 1)
        XCTAssertEqual(startedAnotherCount, 0)
        XCTAssertEqual(backHomeCount, 0)
    }
}
