import SwiftUI

/// F008 Item 1 (v1.9.0). Mute toggle that lives in the top-right of every
/// lesson chrome, left of the exit X. Marisol + Priya: today the only way
/// to mute auto-fire TTS is to open Settings, which is two hops too many
/// in the middle of a lesson — especially on shared laptops or in cafes.
///
/// Bound to `SpeechService.shared.isMuted` (the same UserDefaults-backed
/// flag toggled from Settings; v1.4.1 already wired this). Tapping toggles
/// state, the `⌘M` keyboard shortcut fires the same action, and the icon
/// + accessibility metadata reflect the current state so VoiceOver readers
/// know which side they're on without trial-and-error.
///
/// F009 v1.10.0 blocker fix (Priya): `SpeechService` is now an
/// `ObservableObject` with `@Published var isMuted`, so we observe it
/// directly instead of mirroring into a local `@State`. The mirror was
/// a workaround for the (now removed) UserDefaults-only computed property;
/// dropping it keeps the chrome toggle and every visible `SpeakButton` in
/// lockstep on the same SwiftUI update tick. Test-only injection is
/// retained via `initialIsMuted` (seeds the shared service in init).
struct MuteToggleButton: View {
    @ObservedObject private var speech = SpeechService.shared

    init(initialIsMuted: Bool? = nil) {
        if let initialIsMuted {
            // Test-only seam: align the shared service before the view
            // observes it so unit tests can pin the initial render.
            SpeechService.shared.isMuted = initialIsMuted
        }
    }

    var body: some View {
        Button(action: toggle) {
            Image(systemName: speech.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .imageScale(.large)
        }
        .buttonStyle(.plain)
        // QA + Marisol panel (v1.9.0 patch): use ⌘M instead of bare `M`. A
        // bare-key `M` shortcut silently toggled mute whenever the user typed
        // a word containing the letter (mother, morning, mango) in
        // `write_type_word` / `listen_type`. ⌘M is the HIG-correct modifier
        // for "mute/minimize"-class global app toggles and mirrors the
        // mitigation pattern already used by `ListeningLessonView`'s `S` key.
        .keyboardShortcut("m", modifiers: .command)
        .accessibilityLabel("Silenciar audio")
        // VoiceOver reads label + value, so "Silenciar audio: activado"
        // tells the user the toggle is currently on without trial-and-error.
        .accessibilityValue(speech.isMuted ? "activado" : "desactivado")
        .accessibilityHint("Presiona Cmd+M para alternar")
    }

    private func toggle() {
        // Direct mutation — `SpeechService.isMuted` is `@Published`, so the
        // chrome icon and every observing `SpeakButton` redraw this tick.
        speech.isMuted.toggle()
    }
}
