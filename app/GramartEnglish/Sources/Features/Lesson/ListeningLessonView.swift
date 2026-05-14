import SwiftUI
import LessonKit

/// Question view for listening modes. Replaces the big English word from
/// `LessonQuestionView` with a prominent speaker button; options remain a
/// vertical stack of 4 cards. Auto-plays audio on appear and on question change.
/// Press `S` to repeat.
struct ListeningLessonView: View {
    let question: LessonQuestion
    let mode: LessonMode
    let progress: (current: Int, total: Int)
    let onAnswer: (Int) -> Void
    let onTypedAnswer: (String) -> Void
    let onSkip: () -> Void
    let onExit: () -> Void

    init(
        question: LessonQuestion,
        mode: LessonMode,
        progress: (current: Int, total: Int),
        onAnswer: @escaping (Int) -> Void,
        onTypedAnswer: @escaping (String) -> Void = { _ in },
        onSkip: @escaping () -> Void,
        onExit: @escaping () -> Void
    ) {
        self.question = question
        self.mode = mode
        self.progress = progress
        self.onAnswer = onAnswer
        self.onTypedAnswer = onTypedAnswer
        self.onSkip = onSkip
        self.onExit = onExit
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Button(action: onExit) {
                        Image(systemName: "xmark.circle").imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Salir de la lección")
                    Spacer()
                }

                ProgressHeader(current: progress.current, total: progress.total)

                speakerHero
                    .padding(.top, 8)
                    .onAppear { SpeechService.shared.speakEnglish(question.word) }
                    .onChange(of: question.id) { _, _ in SpeechService.shared.speakEnglish(question.word) }

                Text(prompt)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                if mode.isTyped {
                    TypedAnswerInputView(
                        questionId: question.id,
                        canonical: question.word,
                        onSubmit: onTypedAnswer,
                        onSkip: onSkip
                    )
                    .frame(maxWidth: 540)
                } else {
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }

    private var speakerHero: some View {
        // In typed mode the user is typing into a text field, so a bare-key
        // shortcut on `S` would eat the letter. Use ⌘S there; bare `S` only
        // in the option-based listening modes.
        let shortcut: KeyEquivalent = "s"
        let modifiers: EventModifiers = mode.isTyped ? .command : []
        let hintLabel = mode.isTyped ? "Toca para repetir (⌘S)" : "Toca para repetir (S)"
        return Button {
            SpeechService.shared.speakEnglish(question.word)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.tint)
                    .padding(28)
                    .frame(width: 160, height: 160)
                    .background(.tint.opacity(0.12), in: Circle())
                Text(hintLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: modifiers)
        .accessibilityLabel("Reproducir audio en inglés")
        .accessibilityHint(mode.isTyped ? "Presiona Cmd S para repetir el audio" : "Presiona S para repetir el audio")
    }

    private var prompt: String {
        switch mode {
        case .listenPickWord: return "¿Qué palabra escuchaste?"
        case .listenPickMeaning: return "¿Qué significa la palabra que escuchaste?"
        case .listenType: return "Escucha y escribe la palabra"
        case .readPickMeaning: return "¿Qué significa esta palabra?"
        }
    }
}
