import XCTest
@testable import LessonKit

final class LessonModeTests: XCTestCase {

    func testRawValuesMatchBackendEnum() {
        XCTAssertEqual(LessonMode.readPickMeaning.rawValue, "read_pick_meaning")
        XCTAssertEqual(LessonMode.listenPickWord.rawValue, "listen_pick_word")
        XCTAssertEqual(LessonMode.listenPickMeaning.rawValue, "listen_pick_meaning")
        XCTAssertEqual(LessonMode.listenType.rawValue, "listen_type")
    }

    func testAllCasesCoversAllDefinedModes() {
        // v1.3: 4 from F002 + 3 write_* from F003 = 7 enum values.
        XCTAssertEqual(LessonMode.allCases.count, 7)
        // SHIPPED_MODES excludes write_fill_gaps (deferred to v1.4) so 6 ship in v1.3.
        XCTAssertEqual(SHIPPED_MODES.count, 6)
    }

    func testParsingFromRawString() {
        XCTAssertEqual(LessonMode(rawValue: "listen_pick_word"), .listenPickWord)
        XCTAssertEqual(LessonMode(rawValue: "listen_type"), .listenType)
        XCTAssertNil(LessonMode(rawValue: "write_freeform"))
        XCTAssertNil(LessonMode(rawValue: ""))
    }

    func testIconMapping() {
        XCTAssertEqual(LessonMode.readPickMeaning.iconSystemName, "book")
        for listen: LessonMode in [.listenPickWord, .listenPickMeaning, .listenType] {
            XCTAssertEqual(listen.iconSystemName, "ear", "expected ear icon for \(listen.rawValue)")
        }
    }

    func testDisplayNameAndSubtitleAreSpanish() {
        XCTAssertEqual(LessonMode.readPickMeaning.displayName, "Leer")
        for listen: LessonMode in [.listenPickWord, .listenPickMeaning, .listenType] {
            XCTAssertEqual(listen.displayName, "Escuchar")
        }
        // Subtitles are distinct per mode (7 unique strings after F003).
        let subtitles = Set(LessonMode.allCases.map(\.displaySubtitle))
        XCTAssertEqual(subtitles.count, 7)
    }

    func testListeningFlagMatchesAudioModes() {
        XCTAssertFalse(LessonMode.readPickMeaning.isListening)
        XCTAssertTrue(LessonMode.listenPickWord.isListening)
        XCTAssertTrue(LessonMode.listenPickMeaning.isListening)
        XCTAssertTrue(LessonMode.listenType.isListening)
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
            XCTAssertTrue(cs.displaySubtitle.contains("Próximamente"), "\(cs.rawValue) subtitle should mention Próximamente")
        }
    }
}
