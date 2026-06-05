import SwiftUI

/// F008 Item 1 (v1.9.0). Mute toggle that lives in the top-right of every
/// lesson chrome, left of the exit X. Marisol + Priya: today the only way
/// to mute auto-fire TTS is to open Settings, which is two hops too many
/// in the middle of a lesson — especially on shared laptops or in cafes.
///
/// Bound to `SpeechService.shared.isMuted` (the same UserDefaults-backed
/// flag toggled from Settings; v1.4.1 already wired this). Tapping toggles
/// state, the `M` keyboard shortcut fires the same action, and the icon
/// + accessibility metadata reflect the current state so VoiceOver readers
/// know which side they're on without trial-and-error.
///
/// Why a Bindable wrapper instead of `@AppStorage`: `SpeechService.shared`
/// is the single source of truth (audited by `SpeechCallSiteAuditTests`),
/// and routing through it keeps the toggle from drifting from the auto-fire
/// gate. We mirror the value into `@State` so SwiftUI redraws the icon on
/// the same tick the persisted flag flips.
struct MuteToggleButton: View {
    @State private var isMuted: Bool

    init(initialIsMuted: Bool? = nil) {
        // Allow tests to inject the starting state; in production we always
        // read the live value from SpeechService at construction time.
        _isMuted = State(initialValue: initialIsMuted ?? SpeechService.shared.isMuted)
    }

    var body: some View {
        Button(action: toggle) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .imageScale(.large)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("m", modifiers: [])
        .accessibilityLabel("Silenciar audio")
        // VoiceOver reads label + value, so "Silenciar audio: activado"
        // tells the user the toggle is currently on without trial-and-error.
        .accessibilityValue(isMuted ? "activado" : "desactivado")
        .accessibilityHint("Presiona M para alternar")
    }

    private func toggle() {
        // Flip the persistent flag; mirror it into local @State so the icon
        // updates this tick. We deliberately read back from SpeechService
        // (not just `!isMuted`) so any future side-effects added to the
        // setter (e.g. a coalescing debounce) stay authoritative.
        SpeechService.shared.isMuted.toggle()
        isMuted = SpeechService.shared.isMuted
    }
}
