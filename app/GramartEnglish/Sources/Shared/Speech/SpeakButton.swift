import SwiftUI

struct SpeakButton: View {
    let text: String
    var shortcut: KeyEquivalent? = nil
    var label: String = "Escuchar"
    var size: CGFloat = 18
    /// F007 (v1.8.0). Defaults to `.normal` so existing call-sites keep
    /// their behavior; the new "🐢 lento" affordance opts in.
    var rate: SpeechRate = .normal

    private var symbol: String {
        rate == .slow ? "tortoise.fill" : "speaker.wave.2.fill"
    }

    private var a11yLabel: String {
        rate == .slow
            ? "Reproducir palabra en inglés despacio"
            : "Reproducir palabra en inglés"
    }

    private var a11yHint: String {
        if shortcut == nil {
            return rate == .slow
                ? "Reproduce la palabra en inglés a velocidad lenta"
                : "Reproduce la palabra en inglés"
        }
        let key = String(shortcut!.character).uppercased()
        return rate == .slow
            ? "Presiona \(key) para escuchar despacio"
            : "Presiona \(key) para escuchar"
    }

    var body: some View {
        let button = Button {
            // v1.4.1 F3: explicit user tap → bypass the mute toggle.
            SpeechService.shared.speakEnglish(text, rate: rate, isUserInitiated: true)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(.tint)
                .padding(8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(a11yHint)

        if let shortcut {
            button.keyboardShortcut(shortcut, modifiers: [])
        } else {
            button
        }
    }
}
