import SwiftUI

struct SpeakButton: View {
    let text: String
    var shortcut: KeyEquivalent? = nil
    var label: String = "Escuchar"
    var size: CGFloat = 18

    var body: some View {
        let button = Button {
            // v1.4.1 F3: explicit user tap → bypass the mute toggle.
            SpeechService.shared.speakEnglish(text, isUserInitiated: true)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size))
                .foregroundStyle(.tint)
                .padding(8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // v1.7.0 polish D: drop the verb from the label. The word text is
        // already rendered next to the button as its own a11y element, so
        // saying "Escuchar: wake" here made VO read "wake" three times in
        // a row (label, neighbor element, hint). The hint mentions the "S"
        // shortcut so keyboard users know it without sighted scanning.
        .accessibilityLabel("Reproducir palabra en inglés")
        .accessibilityHint(shortcut == nil ? "Reproduce la palabra en inglés" : "Presiona S para escuchar")

        if let shortcut {
            button.keyboardShortcut(shortcut, modifiers: [])
        } else {
            button
        }
    }
}
