import SwiftUI
import LessonKit

struct LessonQuestionView: View {
    let question: LessonQuestion
    let progress: (current: Int, total: Int)
    let onAnswer: (Int) -> Void
    let onSkip: () -> Void
    let onExit: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: Spacing.sm) {
                    // F008 Item 1 (v1.9.0). Mute toggle sits left of the
                    // exit X so reaching it doesn't require a Settings
                    // detour mid-lesson. `M` is the bare-key shortcut —
                    // see `MuteToggleButton` for the accessibility wiring.
                    MuteToggleButton()
                    Button(action: onExit) {
                        Image(systemName: "xmark.circle")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Salir de la lección")
                    Spacer()
                }

                ProgressHeader(current: progress.current, total: progress.total)

                HStack(spacing: 8) {
                    Text(question.word)
                        // F008 Item 2 (v1.9.0). Token sweep — 56pt literal
                        // replaced with Dynamic-Type-relative font so the
                        // hero word doesn't overflow at accessibility5.
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.5)
                        .accessibilityAddTraits(.isHeader)
                    SpeakButton(text: question.word, shortcut: "s", size: 22, rate: .normal)
                    // F007 (v1.8.0). Slow-rate companion for A1 self-correction.
                    SpeakButton(text: question.word, shortcut: "d", size: 22, rate: .slow)
                }
                .padding(.top, 8)
                .onAppear { SpeechService.shared.speakEnglish(question.word) }
                .onChange(of: question.id) { _, _ in SpeechService.shared.speakEnglish(question.word) }

                Text("¿Qué significa esta palabra?")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        OptionCard(index: index, text: option) { onAnswer(index) }
                    }
                    Button(action: onSkip) {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                            Text("No lo sé")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("0", modifiers: [])
                    .accessibilityLabel("No lo sé — revelar respuesta")
                    .accessibilityHint("Presiona 0 para ver la respuesta sin adivinar")
                }
                .frame(maxWidth: 540)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }
}
