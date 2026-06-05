import AppKit
import SwiftUI

/// F007 (v1.8.0) — design tokens.
///
/// Mariana flagged the visual-debt compounding: hardcoded `.system(size: 80)`
/// in `LessonSummaryView` and `.system(size: 44)` in `WritingLessonView`
/// violate Principle VII (Dynamic Type) — at `accessibility5` they overflow
/// the column and clip behind the safe area. Hardcoded `.green`/`.orange`/
/// `.red` literals don't survive light/dark contrast tuning either.
///
/// This file establishes the token API. We deliberately do NOT propagate the
/// spacing/radius tokens through every view this cycle — that's a v1.9
/// follow-up (Mariana, P2 on her rubric). Only the two worst-offending
/// hardcoded sizes are migrated this release.
///
/// The `Semantic.*` colors fall back to system colors when an asset catalog
/// override isn't provided. v1.8.0 ships without the asset catalog (Mariana:
/// "ship the API first, swap assets later"); v1.9 will add light/dark tuned
/// `.colorset` files keyed on the same names.
public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
}

public enum Radius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
}

/// Background-tint opacity steps. Used by chips / cards where we layer a
/// translucent accent on top of `.background`. Centralised so the alpha
/// values stay consistent across surfaces.
public enum Tint {
    public static let soft: Double = 0.12
    public static let medium: Double = 0.18
    public static let strong: Double = 0.28
}

/// Semantic palette. F009 (v1.10.0) — the v1.8 TODO is paid off.
///
/// Each token ships both ways:
///   1. **Asset catalog** — `Sources/Resources/Assets.xcassets` carries
///      `SemanticSuccess`/`SemanticWarning`/`SemanticError` colorsets
///      with `light` (default) and `dark` (`luminosity = dark`) variants.
///      Tuned to ≥ 4.5:1 contrast on the macOS window background; see
///      `SemanticColorsTests`. An Xcode-driven build compiles the
///      catalog into `Assets.car` and `Color(_:bundle:)` resolves at
///      render time.
///   2. **Programmatic fallback** — when the build pipeline is `swift
///      build` (CI test runs + the SPM-produced executable), SPM copies
///      the `.xcassets` directory uncompiled and `Color(_:bundle:)`
///      returns nil. We back the named token with a `Color` literal
///      that auto-switches between the same light/dark hexes via
///      `ColorScheme`, so the runtime app stays correct.
///
/// Both paths land on the same six sRGB hexes. F010 (v1.11.0) warmed
/// the dark variants per Mariana's latina-warm palette pass — amber
/// shifted from canary-yellow to a softer honey, red from coral-pink
/// to a more saturated coral. Both keep ≥ 4.5:1 contrast on #1E1E1E.
///   success: #0E7C3A light / #4ADE80 dark
///   warning: #B45309 light / #F5C242 dark  (was #FBBF24)
///   error:   #B91C1C light / #EF5B5B dark  (was #F87171)
///
/// Why `.module` and not `.main`: SPM places resources processed via
/// `.process(...)` into the target's per-module bundle, not the app's
/// main bundle. Reading from `.main` would silently fall back to the
/// platform `nil` color (System red, in practice).
public enum Semantic {

    /// Returns the asset-catalog color when the bundle resolves it;
    /// otherwise the fallback closure (which can read `ColorScheme`).
    private static func token(_ name: String, lightHex: UInt32, darkHex: UInt32) -> Color {
        // Probe the bundle once at first use. NSColor exposes whether the
        // lookup succeeded; if it did, we trust the catalog (Xcode build).
        if NSColor(named: NSColor.Name(name), bundle: .module) != nil {
            return Color(name, bundle: .module)
        }
        // SPM-build fallback: synthesise a Color that auto-swaps on
        // ColorScheme. We use `Color(nsColor:)` with a dynamic NSColor
        // so SwiftUI re-evaluates on appearance changes.
        let dynamic = NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            return Self.color(fromHex: isDark ? darkHex : lightHex)
        })
        return Color(nsColor: dynamic)
    }

    private static func color(fromHex hex: UInt32) -> NSColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    public static let success: Color = token("SemanticSuccess", lightHex: 0x0E7C3A, darkHex: 0x4ADE80)
    public static let warning: Color = token("SemanticWarning", lightHex: 0xB45309, darkHex: 0xF5C242)
    public static let error:   Color = token("SemanticError",   lightHex: 0xB91C1C, darkHex: 0xEF5B5B)

    /// Exposed for tests in this module — `Bundle.module` is internal
    /// to the target that owns the resource manifest, so the test target
    /// can't reference it directly. Forwarding via a public accessor
    /// keeps the call-sites symmetric and lets `SemanticColorsTests`
    /// inspect the catalog lookup without filesystem path probing.
    public static var resourceBundle: Bundle { .module }

    /// Test-visible accessor for the raw light/dark hex pair used by the
    /// programmatic fallback. The contrast assertion in
    /// `SemanticColorsTests` consumes these so the catalog (Xcode build)
    /// and the fallback (SPM build) are pinned against the same source
    /// of truth.
    public static let successLightHex: UInt32 = 0x0E7C3A
    public static let successDarkHex:  UInt32 = 0x4ADE80
    public static let warningLightHex: UInt32 = 0xB45309
    public static let warningDarkHex:  UInt32 = 0xF5C242
    public static let errorLightHex:   UInt32 = 0xB91C1C
    public static let errorDarkHex:    UInt32 = 0xEF5B5B
}
