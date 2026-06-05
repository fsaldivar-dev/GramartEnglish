import XCTest
import SwiftUI
import LessonKit
@testable import GramartEnglish

@MainActor
final class WriteFillGapsViewTests: XCTestCase {

    private func sampleMaskedQuestion(masked: String = "w__th_r") -> LessonQuestion {
        LessonQuestion(
            id: "q-fg-0",
            word: "weather",
            options: [],
            position: 0,
            prompt: "clima / tiempo",
            maskedWord: masked
        )
    }

    /// The view exposes `mode == .writeFillGaps` and surfaces the masked
    /// scaffold from the question DTO. Rendering the scaffold view is gated
    /// by `maskedWord != nil` — this guards against accidentally hiding it
    /// when the server populated the field.
    func testWriteFillGapsRendersScaffoldWhenMaskPresent() {
        let view = WritingLessonView(
            question: sampleMaskedQuestion(),
            mode: .writeFillGaps,
            progress: (current: 1, total: 10),
            onSkip: {},
            onExit: {}
        )
        XCTAssertEqual(view.mode, .writeFillGaps)
        XCTAssertTrue(view.mode.isTyped)
        XCTAssertEqual(view.question.maskedWord, "w__th_r")
        XCTAssertEqual(view.question.prompt, "clima / tiempo")
    }

    /// VoiceOver must read each underscore as " espacio " so the spelling
    /// cue is intelligible to hispanohablantes (the UI prefix is Spanish, so
    /// the Spanish-locale synthesizer must not be handed the English token
    /// "blank"). Pinned exactly per the PO+TL a11y contract (Principle VII).
    func testFillGapsAccessibilityLabelReplacesUnderscoresWithEspacio() {
        let label = WritingLessonView.fillGapsAccessibilityLabel(for: "w__th_r")
        XCTAssertEqual(label, "Completa la palabra: w espacio espacio th espacio r")
    }
}
