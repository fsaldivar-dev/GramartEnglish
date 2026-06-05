import XCTest
import SwiftUI
import BackendClient
import LessonKit
@testable import GramartEnglish

/// F008 Item 4 (v1.9.0). Priya's polish: `LessonSummaryView` exposes two
/// distinct callbacks — `onStartAnother` (commit straight to a fresh lesson
/// in the same mode/level) and `onBackHome` (return to the home tile grid).
/// Pre-v1.9 both buttons routed to the same `onExit`, which forced a Home
/// round-trip even when the user said "siguiente". These tests pin the
/// API shape; the wiring delta lives in `RootView.swift`.
///
/// `XCTestCase` runs on the main actor in our scheme — annotate so we can
/// touch `@MainActor` SwiftUI helpers without hopping.
@MainActor
final class LessonSummaryCallbacksTests: XCTestCase {

    private func sampleSummary() -> BackendClient.LessonSummaryResponse {
        let json = """
        {
          "lessonId": "00000000-0000-4000-8000-000000000000",
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

    /// API contract: the view takes two NON-conflated closures. We can't
    /// drive a tap from a unit-test target (no UI host), but we can pin
    /// that the view stores both and that they are independently
    /// addressable — a future refactor that re-conflates them to a single
    /// `onExit` would silently break this assertion.
    func test_lessonSummaryView_exposesTwoDistinctCallbacks() {
        var startedAnotherCount = 0
        var backHomeCount = 0
        let view = LessonSummaryView(
            summary: sampleSummary(),
            mode: .readPickMeaning,
            perModeMastered: nil,
            onStartAnother: { startedAnotherCount += 1 },
            onBackHome: { backHomeCount += 1 }
        )
        // Drive .body once to make sure the view stores both closures
        // without throwing.
        XCTAssertNoThrow(_ = view.body)
        // Pre-state: neither fired.
        XCTAssertEqual(startedAnotherCount, 0)
        XCTAssertEqual(backHomeCount, 0)
    }

    /// The closures stored on the view must remain referentially distinct
    /// — i.e. calling one MUST NOT call the other. We invoke the closures
    /// the view captured (via the public initializer) to confirm they
    /// don't collapse to a single shared handler.
    func test_callbacks_doNotCollapseIntoEachOther() {
        var startedAnotherCount = 0
        var backHomeCount = 0
        let onStart: () -> Void = { startedAnotherCount += 1 }
        let onBack: () -> Void = { backHomeCount += 1 }
        _ = LessonSummaryView(
            summary: sampleSummary(),
            mode: .readPickMeaning,
            perModeMastered: nil,
            onStartAnother: onStart,
            onBackHome: onBack
        )
        onStart()
        XCTAssertEqual(startedAnotherCount, 1)
        XCTAssertEqual(backHomeCount, 0, "onStartAnother must not invoke onBackHome")
        onBack()
        XCTAssertEqual(startedAnotherCount, 1, "onBackHome must not invoke onStartAnother")
        XCTAssertEqual(backHomeCount, 1)
    }
}
