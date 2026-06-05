import XCTest
@testable import LessonKit

final class LessonModeTests: XCTestCase {

    func testRawValuesMatchBackendEnum() {
        XCTAssertEqual(LessonMode.readPickMeaning.rawValue, "read_pick_meaning")
        XCTAssertEqual(LessonMode.listenPickWord.rawValue, "listen_pick_word")
        XCTAssertEqual(LessonMode.listenPickMeaning.rawValue, "listen_pick_meaning")
        XCTAssertEqual(LessonMode.listenType.rawValue, "listen_type")
        XCTAssertEqual(LessonMode.conjugatePickForm.rawValue, "conjugate_pick_form")
    }

    func testAllCasesCoversAllDefinedModes() {
        // v1.6: 4 from F002 + 3 write_* from F003 + 1 conjugate_pick_form from F004 = 8 enum values.
        XCTAssertEqual(LessonMode.allCases.count, 8)
        // SHIPPED_MODES includes conjugate_pick_form as of v1.6.0 — all 8 ship.
        XCTAssertEqual(SHIPPED_MODES.count, 8)
    }

    func testParsingFromRawString() {
        XCTAssertEqual(LessonMode(rawValue: "listen_pick_word"), .listenPickWord)
        XCTAssertEqual(LessonMode(rawValue: "listen_type"), .listenType)
        XCTAssertEqual(LessonMode(rawValue: "conjugate_pick_form"), .conjugatePickForm)
        XCTAssertNil(LessonMode(rawValue: "conjugate_type_form")) // F004 US2 not shipped
        XCTAssertNil(LessonMode(rawValue: ""))
    }

    func testIconMapping() {
        XCTAssertEqual(LessonMode.readPickMeaning.iconSystemName, "book")
        for listen: LessonMode in [.listenPickWord, .listenPickMeaning, .listenType] {
            XCTAssertEqual(listen.iconSystemName, "ear", "expected ear icon for \(listen.rawValue)")
        }
        XCTAssertEqual(LessonMode.conjugatePickForm.iconSystemName, "arrow.triangle.2.circlepath")
    }

    func testDisplayNameAndSubtitleAreSpanish() {
        XCTAssertEqual(LessonMode.readPickMeaning.displayName, "Leer")
        for listen: LessonMode in [.listenPickWord, .listenPickMeaning, .listenType] {
            XCTAssertEqual(listen.displayName, "Escuchar")
        }
        XCTAssertEqual(LessonMode.conjugatePickForm.displayName, "Conjugar")
        XCTAssertEqual(LessonMode.conjugatePickForm.displaySubtitle,
                       "Lee el verbo en español, elige la forma en pasado")
        // Subtitles are distinct per mode (8 unique strings after F004).
        let subtitles = Set(LessonMode.allCases.map(\.displaySubtitle))
        XCTAssertEqual(subtitles.count, 8)
    }

    func testListeningFlagMatchesAudioModes() {
        XCTAssertFalse(LessonMode.readPickMeaning.isListening)
        XCTAssertTrue(LessonMode.listenPickWord.isListening)
        XCTAssertTrue(LessonMode.listenPickMeaning.isListening)
        XCTAssertTrue(LessonMode.listenType.isListening)
        XCTAssertFalse(LessonMode.conjugatePickForm.isListening)
    }

    func testIsTypedCoversTypedModes() {
        let typed: Set<LessonMode> = [.listenType, .writeTypeWord, .writeFillGaps]
        for mode in LessonMode.allCases {
            XCTAssertEqual(mode.isTyped, typed.contains(mode),
                           "\(mode.rawValue) isTyped expected=\(typed.contains(mode))")
        }
    }

    func testIsWritingCoversWriteModes() {
        let writing: Set<LessonMode> = [.writePickWord, .writeTypeWord, .writeFillGaps]
        for mode in LessonMode.allCases {
            XCTAssertEqual(mode.isWriting, writing.contains(mode),
                           "\(mode.rawValue) isWriting expected=\(writing.contains(mode))")
        }
        // Conjugation is explicitly NOT a writing mode (F004 design note).
        XCTAssertFalse(LessonMode.conjugatePickForm.isWriting)
    }

    func testIsConjugationCoversConjugationModes() {
        let conjugation: Set<LessonMode> = [.conjugatePickForm]
        for mode in LessonMode.allCases {
            XCTAssertEqual(mode.isConjugation, conjugation.contains(mode),
                           "\(mode.rawValue) isConjugation expected=\(conjugation.contains(mode))")
        }
    }

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for mode in LessonMode.allCases {
            let data = try encoder.encode(mode)
            let back = try decoder.decode(LessonMode.self, from: data)
            XCTAssertEqual(back, mode)
            // Encoded form is the raw string, not the case name.
            let str = String(data: data, encoding: .utf8)
            XCTAssertEqual(str, "\"\(mode.rawValue)\"")
        }
    }

    func testComingSoonModesAreSeparateFromShipped() {
        let shippedRaws = Set(SHIPPED_MODES.map(\.rawValue))
        for cs in ComingSoonMode.allCases {
            XCTAssertFalse(shippedRaws.contains(cs.rawValue), "\(cs.rawValue) must not be a shipped LessonMode")
        }
        // v1.6.0 lands all previously coming-soon modes, so the enum is empty.
        XCTAssertTrue(ComingSoonMode.allCases.isEmpty)
    }
}
