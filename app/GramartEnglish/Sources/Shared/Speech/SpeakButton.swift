import SwiftUI

struct SpeakButton: View {
    /// F009 v1.10.0 blocker fix (Priya). Observe the shared `SpeechService`
    /// so the icon + a11y label flip the same tick the user hits ⌘M, even
    /// on already-rendered question views. Pre-fix, `body` read
    /// `SpeechService.shared.isMuted` (a plain property), so SwiftUI had
    /// no dependency to track and the indicator only refreshed at the
    /// next question boundary.
    @ObservedObject private var speech = SpeechService.shared

    let text: String
    var shortcut: KeyEquivalent? = nil
    var label: String = "Escuchar"
    var size: CGFloat = 18
    /// F007 (v1.8.0). Defaults to `.normal` so existing call-sites keep
    /// their behavior; the new "🐢 lento" affordance opts in.
    var rate: SpeechRate = .normal
    /// F007 patch (v1.8.0). When the speaker plays a sentence rather than a
    /// single word, the call-site can override the a11y label. Lucía caught
    /// the VerbIntroCard sentence buttons announcing "Reproducir palabra en
    /// inglés" — misleading because the audio is a full example sentence.
    var accessibilityLabelOverride: String? = nil

    /// F009 Item 4 (v1.10.0). Priya's panel: the v1.9.0 dimming was a
    /// good first signal but a learner who's used to seeing the speaker
    /// icon doesn't immediately read "dim" as "muted". Swap to the
    /// `speaker.slash.fill` glyph (same SF Symbol family as the chrome
    /// `MuteToggleButton`) so the affordance is visually consistent.
    /// Tap behavior is unchanged — the v1.4.1 F3 `isUserInitiated`
    /// bypass still plays audio on explicit tap.
    private func symbolName(isMuted: Bool) -> String {
        if isMuted { return "speaker.slash.fill" }
        return rate == .slow ? "tortoise.fill" : "speaker.wave.2.fill"
    }

    private func a11yLabel(isMuted: Bool) -> String {
        let base: String
        if let accessibilityLabelOverride {
            base = accessibilityLabelOverride
        } else {
            base = rate == .slow
                ? "Reproducir palabra en inglés despacio"
                : "Reproducir palabra en inglés"
        }
        // VoiceOver suffix so screen-reader users learn the muted state
        // even when the slash glyph isn't visually informative for them.
        // Spanish wording matches the chrome MuteToggleButton's locale.
        return isMuted ? "\(base) (audio silenciado)" : base
    }

    private var a11yHint: String {
        if shortcut == nil {
            return rate == .slow
                ? "Reproduce el audio a velocidad lenta"
                : "Reproduce el audio en inglés"
        }
        let key = String(shortcut!.character).uppercased()
        return rate == .slow
            ? "Presiona \(key) para escuchar despacio"
            : "Presiona \(key) para escuchar"
    }

    var body: some View {
        // v1.9.0 polish (Priya v1.10 #1). When the global mute is on, dim the
        // speaker glyph so the user has a visual trust signal that audio
        // won't fire — explicit taps still bypass mute (v1.4.1 F3), but the
        // icon should warn before they tap. F009 v1.10.0: read the value
        // off the `@ObservedObject` so SwiftUI redraws on every flip.
        let isMuted = speech.isMuted
        let button = Button {
            // v1.4.1 F3: explicit user tap → bypass the mute toggle.
            speech.speakEnglish(text, rate: rate, isUserInitiated: true)
        } label: {
            Image(systemName: symbolName(isMuted: isMuted))
                .font(.system(size: size))
                .foregroundStyle(isMuted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .padding(8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11yLabel(isMuted: isMuted))
        .accessibilityHint(a11yHint)

        if let shortcut {
            button.keyboardShortcut(shortcut, modifiers: [])
        } else {
            button
        }
    }
}
