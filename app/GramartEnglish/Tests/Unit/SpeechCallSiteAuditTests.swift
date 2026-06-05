import XCTest

/// v1.4.1 F3 — call-site conformance audit.
///
/// Background: Marisol caught a real bug in PR #6 where the listening-mode
/// `speakerHero` button called `SpeechService.shared.speakEnglish(question.word)`
/// without `isUserInitiated: true`. When the user enables the mute toggle in
/// Settings, the hero — the ONLY way to hear the word in listening modes —
/// went silent, contradicting the Settings copy that promises the speaker
/// button always plays.
///
/// To keep this regression from coming back, this test scans the Sources tree
/// for every `speakEnglish(` invocation and partitions them into two buckets:
///
///   - USER-INITIATED tap call-sites (Button actions, etc.) — MUST pass
///     `isUserInitiated: true`.
///   - AUTO-FIRE call-sites (`.onAppear`, `.onChange`, helper methods like
///     `autoSpeak`) — MUST NOT pass the flag, so they honor the mute toggle.
///
/// Rather than try to parse Swift, we maintain a small allow-list of the
/// known call-sites here. The test enforces:
///   1. Every `speakEnglish(` occurrence in Sources is accounted for.
///   2. Every user-tap site carries `isUserInitiated: true`.
///   3. Every auto-fire site does NOT pass the flag (so mute works).
///
/// When you add a new speaker affordance, add it to the right list below.
/// The test will fail loudly if a call-site appears in Sources but is not
/// classified — that is the prompt to think about which bucket it belongs in.
final class SpeechCallSiteAuditTests: XCTestCase {

    /// File-path + 1-based line number of every `speakEnglish(` call in
    /// Sources, classified. The test re-derives the actual call-sites from
    /// disk and cross-checks against this manifest.
    private struct CallSite: Hashable {
        let relativePath: String
        let line: Int
        let userInitiated: Bool
    }

    /// User-tap call-sites — Button actions or other explicit tap handlers.
    /// MUST pass `isUserInitiated: true`.
    private let userTapSites: [CallSite] = [
        // The big circular speaker hero in listening modes — the user's only
        // way to replay the word. Marisol's bug.
        .init(relativePath: "Features/Lesson/ListeningLessonView.swift",
              line: 111, userInitiated: true),
        // Shared 🔊 button used inline next to revealed words.
        .init(relativePath: "Shared/Speech/SpeakButton.swift",
              line: 12, userInitiated: true),
    ]

    /// Auto-fire call-sites — `.onAppear`, `.onChange`, helper methods that
    /// run without an explicit user gesture. MUST NOT pass the flag so the
    /// mute toggle is honored.
    private let autoFireSites: [CallSite] = [
        .init(relativePath: "Features/Lesson/ListeningLessonView.swift",
              line: 51, userInitiated: false),
        .init(relativePath: "Features/Lesson/ListeningLessonView.swift",
              line: 52, userInitiated: false),
        .init(relativePath: "Features/Lesson/LessonQuestionView.swift",
              line: 33, userInitiated: false),
        .init(relativePath: "Features/Lesson/LessonQuestionView.swift",
              line: 34, userInitiated: false),
        .init(relativePath: "Features/Lesson/AnswerFeedbackView.swift",
              line: 58, userInitiated: false),
        .init(relativePath: "Features/Onboarding/PlacementQuestionView.swift",
              line: 107, userInitiated: false),
        .init(relativePath: "Features/Onboarding/PlacementQuestionView.swift",
              line: 109, userInitiated: false),
    ]

    /// Roots up the directory tree from this test file to find the package
    /// `Sources/` directory. We can't rely on `Bundle.module` for source
    /// files (only resources), so walk the file system using `#filePath`.
    private func sourcesRoot() -> URL {
        // Tests/Unit/<this file>.swift -> Tests/Unit -> Tests -> <pkg root>
        let here = URL(fileURLWithPath: #filePath)
        let pkgRoot = here
            .deletingLastPathComponent()  // Unit/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // GramartEnglish/
        return pkgRoot.appendingPathComponent("Sources", isDirectory: true)
    }

    /// Returns every `(relativePath, line, fullLine)` where `speakEnglish(`
    /// literally appears in a `.swift` file under Sources.
    private func discoverCallSites() throws -> [(path: String, line: Int, text: String)] {
        let root = sourcesRoot()
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root,
                                             includingPropertiesForKeys: nil) else {
            XCTFail("Could not enumerate Sources at \(root.path)")
            return []
        }
        var out: [(String, Int, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            for (i, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = String(raw)
                // Skip comments and doc-strings — the protected token is the
                // CALL site, not text that mentions the symbol.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") { continue }
                // Skip the function declaration itself (it lives in
                // SpeechService.swift and contains `speakEnglish(` as part
                // of its signature, not as a call).
                if line.contains("func speakEnglish(") { continue }
                if line.contains("speakEnglish(") {
                    out.append((rel, i + 1, line))
                }
            }
        }
        return out.sorted { ($0.0, $0.1) < ($1.0, $1.1) }
    }

    /// Smoke test: the manifest above accounts for every call-site on disk,
    /// and the `isUserInitiated:` flag matches the bucket each is filed in.
    func test_everySpeakEnglishCallSite_isClassifiedAndCorrect() throws {
        let discovered = try discoverCallSites()

        // Build a lookup keyed by (path, line) for both manifests.
        let manifest: [String: Bool] = Dictionary(
            uniqueKeysWithValues: (userTapSites + autoFireSites).map {
                ("\($0.relativePath):\($0.line)", $0.userInitiated)
            }
        )

        var unmanaged: [String] = []
        var mismatches: [String] = []
        for site in discovered {
            let key = "\(site.path):\(site.line)"
            guard let expectUserInitiated = manifest[key] else {
                unmanaged.append("\(key) -> \(site.text.trimmingCharacters(in: .whitespaces))")
                continue
            }
            let hasFlag = site.text.contains("isUserInitiated: true")
            if hasFlag != expectUserInitiated {
                mismatches.append(
                    "\(key) expected isUserInitiated=\(expectUserInitiated) " +
                    "but file has \(hasFlag) — line: " +
                    site.text.trimmingCharacters(in: .whitespaces)
                )
            }
        }

        // Also: every manifest entry must exist on disk (no stale entries).
        let discoveredKeys = Set(discovered.map { "\($0.path):\($0.line)" })
        let stale = manifest.keys.filter { !discoveredKeys.contains($0) }

        XCTAssertTrue(
            unmanaged.isEmpty,
            "New speakEnglish call-site(s) found in Sources but not classified " +
            "in SpeechCallSiteAuditTests. Decide whether each is a USER-INITIATED " +
            "tap (must pass isUserInitiated: true) or an AUTO-FIRE (must not), " +
            "then add it to the right list:\n" + unmanaged.joined(separator: "\n")
        )
        XCTAssertTrue(
            mismatches.isEmpty,
            "speakEnglish call-site does not match its manifest classification:\n" +
            mismatches.joined(separator: "\n")
        )
        XCTAssertTrue(
            stale.isEmpty,
            "SpeechCallSiteAuditTests manifest has entries that no longer exist " +
            "in Sources (line moved or call removed?). Stale: \(stale.sorted())"
        )
    }
}
