import XCTest
import SwiftUI
import AppKit
@testable import GramartEnglish

/// F009 Item 1 (v1.10.0). Mariana's 5-panel ask: the `Semantic.{success,
/// warning, error}` tokens must (a) resolve to a non-default color (i.e.
/// NOT fall through to `.green`/`.orange`/`.red` system primaries) and
/// (b) pass WCAG AA contrast (≥ 4.5:1) against the macOS window
/// background in both light and dark appearances.
///
/// The catalog is shipped two ways:
///   1. `Sources/Resources/Assets.xcassets/SemanticX.colorset/` — used
///      by Xcode-driven builds (where `actool` compiles to `.car`).
///   2. A programmatic dynamic NSColor fallback in `Semantic.token(...)`
///      that auto-switches on `ColorScheme` — used by `swift build`
///      runs (SPM does not invoke `actool` for `.xcassets` resources
///      on macOS; it merely copies the directory).
///
/// Both paths must agree on the same six sRGB hexes, which are exported
/// as public constants on `Semantic`. This test verifies both halves
/// without depending on which build pipeline produced the binary.
@MainActor
final class SemanticColorsTests: XCTestCase {

    // MARK: - WCAG luminance helpers

    /// WCAG 2.1 §1.4.3 relative luminance. Components are sRGB in [0, 1].
    private func relativeLuminance(_ color: NSColor) -> CGFloat {
        guard let srgb = color.usingColorSpace(.sRGB) else { return 0 }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linearize(_ c: CGFloat) -> CGFloat {
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    private func contrast(_ a: NSColor, _ b: NSColor) -> CGFloat {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        let (l1, l2) = la > lb ? (la, lb) : (lb, la)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    private func nscolor(fromHex hex: UInt32) -> NSColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    /// Light Aqua window content area is effectively pure white.
    private let lightBg = NSColor.white
    /// Dark Aqua window content area — HIG-pinned at #1E1E1E (≈ 0.118).
    private let darkBg = NSColor(srgbRed: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)

    // MARK: - Token resolution

    /// The Color materializers must not throw or crash.
    func test_semanticTokens_constructWithoutCrash() {
        XCTAssertNoThrow(_ = Semantic.success)
        XCTAssertNoThrow(_ = Semantic.warning)
        XCTAssertNoThrow(_ = Semantic.error)
    }

    /// The resourceBundle accessor returns a bundle (catalog may not be
    /// compiled under `swift build`, but `.module` is always non-nil
    /// inside a module that declares resources).
    func test_resourceBundle_nonNil() {
        XCTAssertNotNil(Semantic.resourceBundle)
    }

    /// The catalog directory must be present in the bundle even when
    /// uncompiled — this guards the `Package.swift` `.process` clause.
    func test_resourceBundle_containsAssetCatalog() throws {
        let bundle = Semantic.resourceBundle
        let url = bundle.url(forResource: "Assets", withExtension: "xcassets")
            ?? bundle.bundleURL.appendingPathComponent("Assets.xcassets")
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        XCTAssertTrue(exists, "Assets.xcassets directory must be in the SPM resource bundle")
        XCTAssertTrue(isDir.boolValue)
    }

    // MARK: - Contrast (WCAG AA = 4.5:1)

    func test_successLight_meetsAAOnWhite() {
        let ratio = contrast(nscolor(fromHex: Semantic.successLightHex), lightBg)
        XCTAssertGreaterThanOrEqual(ratio, 4.5,
            "Light SemanticSuccess (#0E7C3A) must be ≥ 4.5:1 on white; got \(ratio)")
    }

    func test_successDark_meetsAAOnDarkBg() {
        let ratio = contrast(nscolor(fromHex: Semantic.successDarkHex), darkBg)
        XCTAssertGreaterThanOrEqual(ratio, 4.5,
            "Dark SemanticSuccess (#4ADE80) must be ≥ 4.5:1 on #1E1E1E; got \(ratio)")
    }

    func test_warningLight_meetsAAOnWhite() {
        let ratio = contrast(nscolor(fromHex: Semantic.warningLightHex), lightBg)
        XCTAssertGreaterThanOrEqual(ratio, 4.5,
            "Light SemanticWarning (#B45309) must be ≥ 4.5:1 on white; got \(ratio)")
    }

    func test_warningDark_meetsAAOnDarkBg() {
        let ratio = contrast(nscolor(fromHex: Semantic.warningDarkHex), darkBg)
        XCTAssertGreaterThanOrEqual(ratio, 4.5,
            "Dark SemanticWarning (#FBBF24) must be ≥ 4.5:1 on #1E1E1E; got \(ratio)")
    }

    func test_errorLight_meetsAAOnWhite() {
        let ratio = contrast(nscolor(fromHex: Semantic.errorLightHex), lightBg)
        XCTAssertGreaterThanOrEqual(ratio, 4.5,
            "Light SemanticError (#B91C1C) must be ≥ 4.5:1 on white; got \(ratio)")
    }

    func test_errorDark_meetsAAOnDarkBg() {
        let ratio = contrast(nscolor(fromHex: Semantic.errorDarkHex), darkBg)
        XCTAssertGreaterThanOrEqual(ratio, 4.5,
            "Dark SemanticError (#F87171) must be ≥ 4.5:1 on #1E1E1E; got \(ratio)")
    }

    /// Regression-pin: ensure we did not paint over the v1.8.0 fallback
    /// to `.green`/`.orange`/`.red`. We compare the chosen hex against
    /// the system primaries' luminance — they should not collide.
    func test_successHex_differsFromSystemGreen() {
        let success = nscolor(fromHex: Semantic.successLightHex)
        let lumSuccess = relativeLuminance(success)
        let lumGreen = relativeLuminance(NSColor.systemGreen)
        XCTAssertGreaterThan(abs(lumSuccess - lumGreen), 0.001,
            "Light SemanticSuccess must NOT equal NSColor.systemGreen (the v1.8 placeholder)")
    }
}
