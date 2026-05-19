import SwiftUI
import LessonKit

/// Question view for writing modes (F003).
///
/// Spanish prompt is the stimulus, English is the answer. Two variants
/// distinguished by `mode.isTyped`:
///   - `write_pick_word`: 4 English option cards (1-4 shortcuts, "No lo sé" with 0).
///   - `write_type_word`: monospaced text field reused from F002 (`TypedAnswerInputView`).
///
/// Unlike listening modes, audio does NOT auto-play on appear — the user is
/// supposed to recall the English from the Spanish without hearing it first.
/// Audio plays once on reveal so the student hears the canonical pronunciation
/// after committing.
struct WritingLessonView: View {
    let question: LessonQuestion
    let mode: LessonMode
    let progress: (current: Int, total: Int)
    let onAnswer: (Int) -> Void
    let onTypedAnswer: (String, Bool) -> Void   // (typedAnswer, hintUsed)
    let onSkip: () -> Void
    let onExit: () -> Void

    init(
        question: LessonQuestion,
        mode: LessonMode,
        progress: (current: Int, total: Int),
        onAnswer: @escaping (Int) -> Void = { _ in },
        onTypedAnswer: @escaping (String, Bool) -> Void = { _, _ in },
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
            VStack(spacing: 22) {
                HStack {
                    Button(action: onExit) {
                        Image(systemName: "xmark.circle").imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Salir de la lección")
                    Spacer()
                }

                ProgressHeader(current: progress.current, total: progress.total)

                spanishPromptHero
                    .padding(.top, 8)

                Text("¿Cómo se dice en inglés?")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if mode.isTyped {
                    TypedAnswerInputView(
                        questionId: question.id,
                        canonical: question.word,
                        onSubmit: { typed, hintUsed in onTypedAnswer(typed, hintUsed) },
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

    @ViewBuilder
    private var spanishPromptHero: some View {
        let prompt = question.prompt ?? question.word
        VStack(spacing: 6) {
            Text(prompt)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Significado en español: \(prompt)")
            Text("español")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(1.5)
        }
        .padding(.horizontal, 16)
    }
}
