import XCTest
@testable import LessonKit

final class LevenshteinTests: XCTestCase {

    func testExactMatchIsZero() {
        XCTAssertEqual(Levenshtein.atMost("weather", "weather", k: 1), 0)
        XCTAssertEqual(Levenshtein.atMost("", "", k: 1), 0)
    }

    func testSingleSubstitution() {
        XCTAssertEqual(Levenshtein.atMost("weather", "wether", k: 1), 1) // wait — "wether" is a deletion (1)
        XCTAssertEqual(Levenshtein.atMost("cat", "cot", k: 1), 1)
    }

    func testSingleInsertion() {
        XCTAssertEqual(Levenshtein.atMost("cat", "cart", k: 1), 1)
    }

    func testSingleDeletion() {
        XCTAssertEqual(Levenshtein.atMost("cart", "cat", k: 1), 1)
    }

    func testTranspositionCostsTwoUnderPlainLevenshtein() {
        // Not Damerau-Levenshtein: "form" -> "from" requires 2 substitutions.
        let dist = Levenshtein.atMost("form", "from", k: 2)
        XCTAssertEqual(dist, 2)
    }

    func testRejectsTransposition_atK1() {
        XCTAssertEqual(Levenshtein.atMost("form", "from", k: 1), Int.max)
    }

    func testShortCircuitsWhenLengthDeltaTooBig() {
        XCTAssertEqual(Levenshtein.atMost("a", "abcdef", k: 1), Int.max)
        XCTAssertEqual(Levenshtein.atMost("abcdef", "a", k: 1), Int.max)
    }

    func testEmptyVsNonEmpty() {
        XCTAssertEqual(Levenshtein.atMost("", "a", k: 1), 1)
        XCTAssertEqual(Levenshtein.atMost("a", "", k: 1), 1)
        XCTAssertEqual(Levenshtein.atMost("", "ab", k: 1), Int.max)
    }

    func testIsWithinIsCaseInsensitiveAndTrimmed() {
        XCTAssertTrue(Levenshtein.isWithin("  WEATHER  ", "weather", k: 0))
        XCTAssertTrue(Levenshtein.isWithin("Weather", "wether", k: 1))
        XCTAssertFalse(Levenshtein.isWithin("weather", "xxxxxxx", k: 1))
    }

    /// SC-004 — common real-world typos must be accepted at threshold 1.
    func testCommonTyposAcceptedAtThresholdOne() {
        let pairs: [(canonical: String, typo: String)] = [
            ("weather", "wether"),      // deletion
            ("language", "languge"),    // deletion
            ("language", "lenguage"),   // substitution
            ("dangerous", "dangerus"),  // deletion
            ("dangerous", "dangrous"),  // deletion
            ("important", "imporant"),  // deletion
            ("expensive", "expensiv"),  // deletion
            ("beautiful", "beatiful"),  // deletion
            ("necessary", "necesary"),  // deletion
            ("February", "Febuary"),    // deletion
            ("restaurant", "restaurnt"),// deletion
            ("government", "goverment"),// deletion
            ("vegetable", "vegtable"),  // deletion
            ("different", "diferent"),  // deletion
            ("chocolate", "chocolat"),  // deletion
            ("difficult", "dificult"),  // deletion
            ("knowledge", "knowlege"),  // deletion
            ("listen", "lisen"),        // deletion
            ("interesting", "intersting"), // deletion
            ("birthday", "birhday"),    // deletion
        ]
        var accepted = 0
        for p in pairs {
            if Levenshtein.isWithin(p.typo, p.canonical, k: 1) { accepted += 1 }
        }
        let ratio = Double(accepted) / Double(pairs.count)
        XCTAssertGreaterThanOrEqual(ratio, 0.9, "expected ≥90% acceptance, got \(accepted)/\(pairs.count)")
    }
}
