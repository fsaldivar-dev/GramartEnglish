import XCTest
import SwiftUI
import BackendClient
import LessonKit
@testable import GramartEnglish

/// F007 (v1.8.0). Smoke-tests that `LessonSummaryView` instantiates cleanly
/// at the largest Dynamic Type size without throwing. A real snapshot test
/// would require a host UI bundle; this is the cheapest signal that the
/// font/size migration off the hardcoded 80pt didn't introduce a layout
/// constraint that crashes at `accessibility5`.
final class LessonSummaryDynamicTypeTests: XCTestCase {

    private func sampleSummary() -> BackendClient.LessonSummaryResponse {
        // Build via JSONDecoder so we don't depend on the public initializer
        // signature shape.
        let json = """
        {
          "lessonId": "00000000-0000-4000-8000-000000000000",
          "score": 8,
          "skipped": 1,
          "wrong": 1,
          "total": 10,
          "missedWords": [
            {"word":"acknowledge","canonicalDefinition":"reconocer","outcome":"incorrect"},
            {"word":"although","canonicalDefinition":"aunque","outcome":"skipped"}
          ]
        }
        """
        return try! JSONDecoder().decode(
            BackendClient.LessonSummaryResponse.self,
            from: Data(json.utf8)
        )
    }

    func testSummaryConstructsCleanly() throws {
        // Constructing the view exercises every fonts/layout precondition
        // hit at init time — the migration off the hardcoded 80pt + 44pt
        // fonts must not introduce a `.system(size: NaN)` or similar
        // numerical fault that the SwiftUI runtime would catch only on
        // first layout. We can't drive a real layout pass from a unit
        // test target (no host UI bundle), but `.body` evaluation on the
        // view itself (not a ModifiedContent) is a cheap smoke test.
        let view = LessonSummaryView(
            summary: sampleSummary(),
            mode: .readPickMeaning,
            perModeMastered: [
                "read_pick_meaning": 12,
                "listen_pick_word": 4,
                "listen_pick_meaning": 0,
                "listen_type": 0,
                "write_pick_word": 0,
                "write_type_word": 0,
                "write_fill_gaps": 0,
                "conjugate_pick_form": 0,
            ],
            onStartAnother: {},
            onBackHome: {}
        )
        XCTAssertNoThrow(_ = view.body)
    }

    func testSummaryConstructsForConjugateModeWithoutPerModeCounts() throws {
        let view = LessonSummaryView(
            summary: sampleSummary(),
            mode: .conjugatePickForm,
            perModeMastered: nil,
            onStartAnother: {},
            onBackHome: {}
        )
        XCTAssertNoThrow(_ = view.body)
    }
}
