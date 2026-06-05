import SwiftUI
import LessonKit

/// Question view for `conjugate_pick_form` (F004 US1, v1.6.0).
///
/// Prompt shape: "Pasado simple de **<spanish_infinitive>**" — Spanish verb
/// infinitive with markdown emphasis on the verb itself.
///
/// Answer: pick the English past-simple form from 4 option cards. Same
/// `OptionCard` reuse pattern as `WritingLessonView` for `write_pick_word`,
/// but with no audio auto-play (the student must recall the form from the
/// Spanish prompt, not from hearing the base).
struct ConjugationLessonView: View {
    let question: LessonQuestion
    let progress: (current: Int, total: Int)
    let onAnswer: (Int) -> Void
    let onSkip: () -> Void
    let onExit: () -> Void

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

                conjugationPromptHero
                    .padding(.top, 8)

                Text("Elige la forma en pasado")
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

    /// The hero strips the `**…**` markdown emphasis from the server-provided
    /// prompt and styles the Spanish infinitive distinctly. We keep the test
    /// hook (`Self.spanishInfinitive(from:)`) static so XCTest can pin the
    /// parser without instantiating the view.
    @ViewBuilder
    private var conjugationPromptHero: some View {
        let infinitive = Self.spanishInfinitive(from: question.prompt) ?? (question.verbBase ?? "")
        VStack(spacing: 8) {
            Text("Pasado simple de")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.secondary)
            Text(infinitive)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("español")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(1.5)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pasado simple del verbo en español: \(infinitive)")
        .accessibilityHint("Elige la forma correcta del pasado simple en inglés")
    }

    /// Parses "Pasado simple de **ir**" → "ir". Returns nil if the prompt is
    /// missing or malformed (caller falls back to `verbBase`).
    static func spanishInfinitive(from prompt: String?) -> String? {
        guard let prompt else { return nil }
        // Find the **…** segment.
        guard let openRange = prompt.range(of: "**") else { return nil }
        let afterOpen = prompt[openRange.upperBound...]
        guard let closeRange = afterOpen.range(of: "**") else { return nil }
        let infinitive = afterOpen[..<closeRange.lowerBound]
        let trimmed = infinitive.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
