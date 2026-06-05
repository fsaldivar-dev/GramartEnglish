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
                    if mode == .writeFillGaps, let masked = question.maskedWord {
                        fillGapsScaffold(masked: masked)
                    }
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

    /// Renders the `write_fill_gaps` scaffolding (e.g. `w__th_r`) above the
    /// text input. The a11y label replaces every `_` with " espacio " so
    /// the Spanish-locale VoiceOver synthesizer reads gaps naturally for
    /// hispanohablantes (instead of awkwardly pronouncing the English word
    /// "blank").
    /// `.accessibilityElement(children: .combine)` groups the scaffold with
    /// its label so VoiceOver doesn't fragment it.
    @ViewBuilder
    private func fillGapsScaffold(masked: String) -> some View {
        VStack(spacing: 4) {
            Text(masked)
                .font(.system(.title2, design: .monospaced))
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.fillGapsAccessibilityLabel(for: masked))
        .accessibilityHint("Escribe la palabra completa en inglés")
    }

    /// Builds the VoiceOver label for `write_fill_gaps`. Replaces every `_`
    /// with " espacio " (with surrounding spaces collapsed) and prefixes it
    /// with the Spanish instruction. The Spanish word is intentional: the
    /// UI is es-MX, and the Spanish VoiceOver synthesizer would otherwise
    /// pronounce the English token "blank" awkwardly for hispanohablantes
    /// (Principle VII). Pinned by `WriteFillGapsViewTests`.
    ///
    /// v1.5.2 polish (Marisol): for very short masks (length ≤ 4) with the
    /// shape "one visible letter at position 0 + only gaps after",
    /// emit a natural-language form ("g, falta una letra", "e__, faltan dos
    /// letras") instead of the curt "g espacio" / "e espacio espacio" rhythm.
    /// Longer masks (and odd shapes like multiple visible letters) keep the
    /// original ` espacio ` form, which scans fine for words like `weather`.
    static func fillGapsAccessibilityLabel(for masked: String) -> String {
        // Short-mask natural-language path: exactly one visible letter at
        // position 0, all remaining chars are gaps, total length ≤ 4.
        if masked.count >= 2, masked.count <= 4 {
            let chars = Array(masked)
            let head = chars[0]
            let rest = chars.dropFirst()
            if head != "_", rest.allSatisfy({ $0 == "_" }) {
                let gapWord: String
                switch rest.count {
                case 1: gapWord = "falta una letra"
                case 2: gapWord = "faltan dos letras"
                case 3: gapWord = "faltan tres letras"
                default: gapWord = "" // unreachable given length bounds
                }
                if !gapWord.isEmpty {
                    return "Completa la palabra: \(head), \(gapWord)"
                }
            }
        }

        var spoken = ""
        for ch in masked {
            if ch == "_" {
                spoken += " espacio "
            } else {
                spoken.append(ch)
            }
        }
        // Collapse repeated whitespace produced by the replacements and trim.
        let collapsed = spoken
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        return "Completa la palabra: \(collapsed)"
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
