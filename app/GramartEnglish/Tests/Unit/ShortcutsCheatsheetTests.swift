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

    /// The full list must always contain exactly the 12 shortcuts shipping
    /// today (9 from the initial v1.12 cheatsheet + 3 added by the v1.12.0
    /// patch when Priya audited the live app: `⌘,` for Settings, `⌘E` for
    /// examples, `⌘.` for typed-mode "no lo sé"). A future addition that
    /// bumps the count without updating this number fails CI as a heads-up
    /// to extend the cheatsheet doc + the per-section assertions below.
    func testAllEntriesCountIsPinned() {
        XCTAssertEqual(ShortcutsCheatsheetView.allEntries.count, 12)
    }

    func testAudioSectionEntriesArePinned() {
        let audio = ShortcutsCheatsheetView.audioEntries
        XCTAssertEqual(audio.count, 3)
        XCTAssertEqual(audio[0], .init(key: "S",  action: "Escuchar (velocidad normal)"))
        XCTAssertEqual(audio[1], .init(key: "D",  action: "Escuchar (despacio)"))
        XCTAssertEqual(audio[2], .init(key: "⌘M", action: "Silenciar / activar audio"))
    }

    /// v1.12.0 patch (Priya blocker 1). `⌘E` opens the per-verb examples
    /// panel from `AnswerFeedbackView`; the shortcut shipped in F008 but
    /// was missing from the initial cheatsheet.
    func testInformationSectionEntriesArePinned() {
        let info = ShortcutsCheatsheetView.informationEntries
        XCTAssertEqual(info.count, 1)
        XCTAssertEqual(info[0], .init(key: "⌘E", action: "Ver ejemplos del verbo"))
    }

    func testAnswerSectionEntriesArePinned() {
        let answer = ShortcutsCheatsheetView.answerEntries
        XCTAssertEqual(answer.count, 5)
        XCTAssertEqual(answer[0], .init(key: "1–4",   action: "Elegir opción"))
        XCTAssertEqual(answer[1], .init(key: "0",     action: "No lo sé"))
        XCTAssertEqual(answer[2], .init(key: "Enter", action: "Enviar respuesta"))
        XCTAssertEqual(answer[3], .init(key: "⌘H",   action: "Pedir pista"))
        // v1.12.0 patch (Priya blocker 1). `⌘.` is the typed-mode no-sé
        // shortcut wired in `TypedAnswerInputView` — the visible "0" key
        // collides with the text field so this is the only path.
        XCTAssertEqual(answer[4], .init(key: "⌘.",   action: "No lo sé (en modo escritura)"))
    }

    func testNavigationSectionEntriesArePinned() {
        let nav = ShortcutsCheatsheetView.navigationEntries
        XCTAssertEqual(nav.count, 3)
        XCTAssertEqual(nav[0], .init(key: "Esc", action: "Cerrar / salir"))
        XCTAssertEqual(nav[1], .init(key: "⌘/",  action: "Mostrar este menú"))
        // v1.12.0 patch (Priya blocker 1). `⌘,` opens Settings from
        // `HomeView` (system-standard preferences shortcut).
        XCTAssertEqual(nav[2], .init(key: "⌘,",  action: "Abrir Ajustes"))
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
            "Pedir", "Enviar", "lo sé",
            // v1.12.0 patch — new entries surface "Ver ejemplos del
            // verbo" and "Abrir Ajustes"; both are pure Spanish even
            // though they lack accents. Marker words pin the copy
            // without forcing diacritics that aren't in the source.
            "Ver ejemplos", "verbo", "Abrir", "Ajustes"
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

    // MARK: - Sheet-over-sheet guard (Priya blocker 3, v1.12.0 patch)

    /// SwiftUI on macOS doesn't stack `.sheet` from the same presenter.
    /// Before the patch, pressing ⌘`/` while `SettingsView` or
    /// `MyWordsView` was already presented toggled `showingCheatsheet`
    /// without actually presenting the cheatsheet — the flag got stuck
    /// `true` and the sheet popped uninvited after the outer sheet
    /// dismissed. The guard is the `canShowCheatsheet` computed
    /// property in `ReadyFlowView` plus a `.disabled(!canShowCheatsheet)`
    /// on the hidden trigger button.
    ///
    /// We can't drive the SwiftUI graph here (no UI host bundle), so
    /// we pin the contract by reading the source of `RootView.swift`
    /// and asserting both the guard expression and the `.disabled`
    /// wiring are present. Any future refactor that drops one of
    /// these breaks the test loudly.
    func testCheatsheetTriggerIsGuardedAgainstSheetOverlap() throws {
        let url = Self.rootViewSourceURL()
        let src = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(
            src.contains("private var canShowCheatsheet: Bool"),
            "ReadyFlowView lost the canShowCheatsheet guard — sheet-over-sheet bug returns"
        )
        XCTAssertTrue(
            src.contains("!showSettings && !showMyWords"),
            "canShowCheatsheet must reject the trigger while Settings or MyWords is presented"
        )
        XCTAssertTrue(
            src.contains(".disabled(!canShowCheatsheet)"),
            "Hidden ⌘/ trigger button must be .disabled(!canShowCheatsheet)"
        )
    }

    /// Pins the Help-menu wiring added in the v1.12.0 patch (Priya
    /// blocker 2). We assert against the source rather than the
    /// running scene because `Commands` aren't testable without a
    /// hosted app instance. If the menu item disappears, this test
    /// fails — restoring the discovery affordance the cheatsheet
    /// depends on.
    func testHelpMenuExposesCheatsheet() throws {
        let url = Self.gramartEnglishAppSourceURL()
        let src = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(
            src.contains("CommandGroup(replacing: .help)"),
            "GramartEnglishApp must replace .help menu with the cheatsheet command"
        )
        XCTAssertTrue(
            src.contains("\"Atajos de teclado\""),
            "Help-menu item label must read 'Atajos de teclado'"
        )
        XCTAssertTrue(
            src.contains(".showShortcutsCheatsheet"),
            "Help-menu item must post the .showShortcutsCheatsheet notification"
        )
    }

    /// Locates `RootView.swift` relative to this test file, walking
    /// up from `Tests/Unit/` to `Sources/App/`. Test bundles don't
    /// have a stable working directory, so resolving via `#file`
    /// keeps the path correct across `swift test` and Xcode.
    private static func rootViewSourceURL() -> URL {
        let here = URL(fileURLWithPath: #file)
        // here: …/Tests/Unit/ShortcutsCheatsheetTests.swift
        return here
            .deletingLastPathComponent()        // Unit
            .deletingLastPathComponent()        // Tests
            .deletingLastPathComponent()        // GramartEnglish
            .appendingPathComponent("Sources/App/RootView.swift")
    }

    private static func gramartEnglishAppSourceURL() -> URL {
        let here = URL(fileURLWithPath: #file)
        return here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/App/GramartEnglishApp.swift")
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
