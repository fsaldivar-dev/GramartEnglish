import SwiftUI
import LessonKit

struct AnswerFeedbackView: View {
    let question: LessonQuestion
    let outcome: AnswerOutcome
    let progress: (current: Int, total: Int)
    let isLast: Bool
    let mode: LessonMode
    let typedAnswerEcho: String?
    let onNext: () -> Void
    let onShowExamples: () -> Void

    init(
        question: LessonQuestion,
        outcome: AnswerOutcome,
        progress: (current: Int, total: Int),
        isLast: Bool,
        mode: LessonMode = .readPickMeaning,
        typedAnswerEcho: String? = nil,
        onNext: @escaping () -> Void,
        onShowExamples: @escaping () -> Void
    ) {
        self.question = question
        self.outcome = outcome
        self.progress = progress
        self.isLast = isLast
        self.mode = mode
        self.typedAnswerEcho = typedAnswerEcho
        self.onNext = onNext
        self.onShowExamples = onShowExamples
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProgressHeader(current: progress.current, total: progress.total)

                HStack(spacing: 10) {
                    Image(systemName: badgeIcon).imageScale(.large)
                    Text(badgeText).font(.title3.weight(.semibold))
                }
                .foregroundStyle(badgeColor)
                .accessibilityElement(children: .combine)

                HStack(spacing: 8) {
                    Text(question.word)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                    SpeakButton(text: question.word, shortcut: "s", size: 18)
                }
                .onAppear {
                    // FR-008 + FR-012 — re-speak the canonical on reveal for any
                    // listening mode, with a small debounce so the reveal animation
                    // settles before audio starts.
                    if mode.isListening {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            SpeechService.shared.speakEnglish(question.word)
                        }
                    }
                }

                if mode.isTyped, let echo = typedAnswerEcho, !echo.isEmpty,
                   echo.lowercased() != question.word.lowercased() {
                    // FR-007a — typed answer accepted via Levenshtein ≤ 1: show
                    // the user's input struck-through below the canonical word.
                    VStack(spacing: 4) {
                        Text("Casi — la palabra es:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(echo)
                            .font(.system(size: 22, design: .rounded))
                            .foregroundStyle(.secondary)
                            .strikethrough()
                            .accessibilityLabel("Lo que escribiste: \(echo), tachado")
                    }
                    .padding(.bottom, 4)
                }

                if !mode.isTyped {
                    VStack(spacing: 8) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            AnswerRow(
                                index: index,
                                text: option,
                                isCorrect: index == outcome.correctIndex,
                                isChosen: outcome.chosenIndex.map { $0 == index } ?? false
                            )
                        }
                    }
                    .frame(maxWidth: 540)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Definición (en inglés)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        SpeakButton(text: outcome.canonicalDefinition, size: 14)
                    }
                    Text(outcome.canonicalDefinition)
                        .font(.body)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .frame(maxWidth: 540, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))

                Button(action: onShowExamples) {
                    Label("Ver cómo se usa esta palabra", systemImage: "sparkles")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("e", modifiers: .command)
                .accessibilityHint("Abre frases de ejemplo para esta palabra")

                Button(action: onNext) {
                    Text(isLast ? "Ver resultado" : "Siguiente")
                        .frame(minWidth: 220)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }

    private var badgeIcon: String {
        switch outcome.kind {
        case .correct: return "checkmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        case .skipped: return "questionmark.circle.fill"
        }
    }

    private var badgeText: String {
        switch outcome.kind {
        case .correct: return "¡Correcto!"
        case .incorrect: return "No del todo"
        case .skipped: return "Aquí está la respuesta"
        }
    }

    private var badgeColor: Color {
        switch outcome.kind {
        case .correct: return .green
        case .incorrect: return .red
        case .skipped: return .orange
        }
    }
}

private struct AnswerRow: View {
    let index: Int
    let text: String
    let isCorrect: Bool
    let isChosen: Bool

    private var borderColor: Color {
        if isCorrect { return .green }
        if isChosen { return .red }
        return .clear
    }

    private var background: some ShapeStyle {
        AnyShapeStyle(.background.secondary)
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(String(index + 1))
                .font(.system(.body, design: .monospaced))
                .frame(width: 28, height: 28)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            Text(text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isCorrect {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Correct answer")
            } else if isChosen {
                Image(systemName: "xmark")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Your answer")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: 2)
        )
    }
}
