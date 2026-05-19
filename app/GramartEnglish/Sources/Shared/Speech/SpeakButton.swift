import SwiftUI

struct SpeakButton: View {
    let text: String
    var shortcut: KeyEquivalent? = nil
    var label: String = "Escuchar"
    var size: CGFloat = 18

    var body: some View {
        let button = Button {
            SpeechService.shared.speakEnglish(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size))
                .foregroundStyle(.tint)
                .padding(8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label): \(text)")
        .accessibilityHint("Reproduce la palabra en inglés")

        if let shortcut {
            button.keyboardShortcut(shortcut, modifiers: [])
        } else {
            button
        }
    }
}
