import SwiftUI

/// A focus ring overlay that respects system Increase Contrast.
public struct FocusRingModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    let isFocused: Bool

    public func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    Color.accentColor.opacity(isFocused ? (contrast == .increased ? 1.0 : 0.7) : 0),
                    lineWidth: isFocused ? 3 : 0
                )
        )
    }
}

public extension View {
    /// Adds a system-respecting focus ring overlay.
    func focusRing(_ isFocused: Bool) -> some View {
        modifier(FocusRingModifier(isFocused: isFocused))
    }
}

/// Transitions that collapse to a fade when Reduce Motion is active.
public struct A11yTransition {
    public static func slideOrFade() -> AnyTransition {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return .opacity
        }
        return .move(edge: .trailing).combined(with: .opacity)
    }
}
