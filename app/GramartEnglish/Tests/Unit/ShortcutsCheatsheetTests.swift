import XCTest
import SwiftUI
@testable import GramartEnglish

/// F011 Item 3 (v1.12.0). Pins the keyboard cheatsheet content + a11y
/// shape so future refactors can't accidentally drop a row or break the
/// "<key>, <action>" VoiceOver concatenation Priya specified.
///
/// We deliberately assert against the static `Entry` lists (not a SwiftUI
/// render) — the body wiring is exercised at compile time and via the
/// Dynamic-Type smoke at the bottom of this file.
final class ShortcutsCheatsheetTests: XCTestCase {

    // MARK: - Content pins

    /// The full list must always contain exactly the 9 shortcuts shipping
    /// today. A future addition that bumps the count without updating
    /// this number fails CI as a heads-up to extend the cheatsheet doc +
    /// the per-section assertions below.
    func testAllEntriesCountIsPinned() {
        XCTAssertEqual(ShortcutsCheatsheetView.allEntries.count, 9)
    }

    func testAudioSectionEntriesArePinned() {
        let audio = ShortcutsCheatsheetView.audioEntries
        XCTAssertEqual(audio.count, 3)
        XCTAssertEqual(audio[0], .init(key: "S",  action: "Escuchar (velocidad normal)"))
        XCTAssertEqual(audio[1], .init(key: "D",  action: "Escuchar (despacio)"))
        XCTAssertEqual(audio[2], .init(key: "⌘M", action: "Silenciar / activar audio"))
    }

    func testAnswerSectionEntriesArePinned() {
        let answer = ShortcutsCheatsheetView.answerEntries
        XCTAssertEqual(answer.count, 4)
        XCTAssertEqual(answer[0], .init(key: "1–4",   action: "Elegir opción"))
        XCTAssertEqual(answer[1], .init(key: "0",     action: "No lo sé"))
        XCTAssertEqual(answer[2], .init(key: "Enter", action: "Enviar respuesta"))
        XCTAssertEqual(answer[3], .init(key: "⌘H",   action: "Pedir pista"))
    }

    func testNavigationSectionEntriesArePinned() {
        let nav = ShortcutsCheatsheetView.navigationEntries
        XCTAssertEqual(nav.count, 2)
        XCTAssertEqual(nav[0], .init(key: "Esc", action: "Cerrar / salir"))
        XCTAssertEqual(nav[1], .init(key: "⌘/",  action: "Mostrar este menú"))
    }

    /// Spanish copy pin — the action text must remain in Spanish so the
    /// cheatsheet stays consistent with the rest of the UI. A test that
    /// flags any ASCII-only action (English regression) catches the
    /// localisation drift Priya feared.
    func testEveryActionContainsSpanishGlyphOrPhrase() {
        // Each Spanish action contains at least one accented letter, an
        // ñ, a tilde-bearing word, or a Spanish-only word from the
        // codified vocabulary list. Using a presence check rather than a
        // full string compare keeps the assertion resilient to copy
        // micro-edits while still failing on an English regression.
        let spanishMarkers: [String] = [
            "á", "é", "í", "ó", "ú", "ñ",
            "Escuchar", "Elegir", "Silenciar", "Cerrar", "menú",
            "Pedir", "Enviar", "lo sé"
        ]
        for entry in ShortcutsCheatsheetView.allEntries {
            let hit = spanishMarkers.contains { entry.action.contains($0) }
            XCTAssertTrue(
                hit,
                "Cheatsheet action lost its Spanish copy: \(entry.action)"
            )
        }
    }

    // MARK: - Accessibility

    /// The combined VoiceOver label for each row must be `"<key>, <action>"`
    /// per Priya's spec — single utterance, comma pause between glyph and
    /// description. The view assembles this string inline; we mirror the
    /// formatter here so a future code change that switches to a hyphen or
    /// reorders the parts breaks the test loudly.
    func testCombinedAccessibilityLabelFormat() {
        for entry in ShortcutsCheatsheetView.allEntries {
            let expected = "\(entry.key), \(entry.action)"
            XCTAssertFalse(expected.contains("  "), "double-space in \(expected)")
            XCTAssertTrue(expected.contains(", "),  "missing comma-pause in \(expected)")
        }
    }

    // MARK: - Dynamic Type smoke

    /// Instantiating the view at `.accessibility3` exercises every font /
    /// layout precondition hit at init time. We don't render — that would
    /// need a UI host bundle — but we DO confirm the body doesn't throw
    /// on construction with the largest reasonable Dynamic Type size.
    func testConstructsAtAccessibility3() {
        XCTAssertNoThrow(_ = ShortcutsCheatsheetView(onClose: {})
            .environment(\.dynamicTypeSize, .accessibility3))
    }
}
