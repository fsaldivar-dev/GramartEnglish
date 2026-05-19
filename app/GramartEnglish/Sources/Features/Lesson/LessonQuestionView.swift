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
                HStack {
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
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    SpeakButton(text: question.word, shortcut: "s", size: 22)
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
