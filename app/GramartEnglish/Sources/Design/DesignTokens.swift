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

/// Semantic palette. v1.8.0 falls back to the system primaries; v1.9 will
/// swap each to a tuned `Color("SemanticSuccess")` etc. via asset catalog
/// without touching call-sites.
public enum Semantic {
    // TODO(v1.9): migrate to Color("SemanticSuccess") asset with
    //             light/dark variants tuned for AA contrast on .background.
    public static let success: Color = .green
    // TODO(v1.9): migrate to Color("SemanticWarning") asset.
    public static let warning: Color = .orange
    // TODO(v1.9): migrate to Color("SemanticError") asset.
    public static let error: Color = .red
}
