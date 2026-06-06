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
                        // F008 Item 2 (v1.9.0). Token sweep — 36pt literal.
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.semibold)
                        .minimumScaleFactor(0.6)
                    SpeakButton(text: question.word, shortcut: "s", size: 18, rate: .normal)
                    // F007 (v1.8.0). Slow-rate companion for A1 self-correction.
                    SpeakButton(text: question.word, shortcut: "d", size: 18, rate: .slow)
                }
                .onAppear {
                    // FR-008 + FR-012 — re-speak the canonical on reveal for any
                    // listening mode, with a small debounce so the reveal animation
                    // settles before audio starts.
                    // v1.13: also auto-speak on `.correct` outcome regardless of mode —
                    // positive audio reinforcement on a right answer (user-requested).
                    // Mute is respected automatically by `speakEnglish` (no
                    // `isUserInitiated: true` here).
                    if mode.isListening || outcome.kind == .correct {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            SpeechService.shared.speakEnglish(question.word)
                        }
                    }
                }

                // F007 (v1.8.0). Over-regularization teaching line. Shown
                // BEFORE the typed-echo block so the diagnosis lands first;
                // the strikethrough echo then concretises which character
                // sequence to unlearn.
                if let hint = outcome.feedbackHint, !hint.isEmpty {
                    Text(.init(hint))
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: 540, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(Semantic.warning.opacity(Tint.soft))
                        )
                        .accessibilityLabel(hint)
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
                            // F008 Item 2 (v1.9.0). Token sweep — 22pt literal.
                            .font(.system(.title3, design: .rounded))
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
                // F010 (v1.11.0). Token sweep — 10pt literal rounds to Radius.md (12).
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: Radius.md))

                // F008 Item 3 (v1.9.0). False-friend warning chip — Lucía's
                // L1-transfer belt. Surfaced below the canonical reveal so
                // it lands AFTER the learner has committed an answer,
                // disambiguating the trap at the moment of recall instead
                // of as a pre-question hint. Absent for the ~98% of words
                // without a belt entry.
                if let falseFriend = question.falseFriendEs, !falseFriend.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        // v1.9.0 polish (Lucía). `exclamationmark.triangle.fill`
                        // read as an error/warning. The belt entry is a
                        // pedagogical tip ("ojo aquí"), not a failure, so we
                        // use `lightbulb.fill`. Warning tint is preserved
                        // so the chip stays visually distinct from the rest
                        // of the feedback card.
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Semantic.warning)
                            .accessibilityHidden(true)
                        Text(falseFriend)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.sm)
                    .frame(maxWidth: 540, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(Semantic.warning.opacity(Tint.soft))
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Aviso de falso amigo: \(falseFriend)")
                }

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

    // F010 (v1.11.0). Mariana flag from v1.10 review — raw `.green`/`.red`/
    // `.orange` literals don't get the WCAG-tuned light/dark hexes that ship
    // through `Semantic.*`. Migrating preserves contrast on the dark
    // appearance without changing the badge semantics.
    private var badgeColor: Color {
        switch outcome.kind {
        case .correct: return Semantic.success
        case .incorrect: return Semantic.error
        case .skipped: return Semantic.warning
        }
    }
}

private struct AnswerRow: View {
    let index: Int
    let text: String
    let isCorrect: Bool
    let isChosen: Bool

    // F010 (v1.11.0). Same Semantic migration as `badgeColor` above —
    // the row border was on the v1.10 audit list.
    private var borderColor: Color {
        if isCorrect { return Semantic.success }
        if isChosen { return Semantic.error }
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
                // F010 (v1.11.0). 6pt → Radius.sm (8); preserves chip visual rhythm.
                .background(.quaternary, in: RoundedRectangle(cornerRadius: Radius.sm))
            Text(text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isCorrect {
                Image(systemName: "checkmark")
                    .foregroundStyle(Semantic.success)
                    .accessibilityLabel("Correct answer")
            } else if isChosen {
                Image(systemName: "xmark")
                    .foregroundStyle(Semantic.error)
                    .accessibilityLabel("Your answer")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        // F010 (v1.11.0). 10pt → Radius.md (12).
        .background(background, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(borderColor, lineWidth: 2)
        )
    }
}
