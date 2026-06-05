import SwiftUI
import BackendClient

/// F006 (v1.7.0) — "Conoce el verbo" pre-conjugation micro-card.
///
/// Shown ONCE per `(macInstall, verbBase)` immediately before the first
/// `conjugate_pick_form` question for that verb. Dismissal paths (CTA, Esc,
/// click-outside) all route through the same `onDismiss` callback so the
/// coordinator's `markSeen + clear pendingIntro + advance` sequence is
/// atomic at the call site.
///
/// HIG / a11y notes:
/// - The Spanish strings carry `.environment(\.locale, Locale(identifier: "es-MX"))`
///   so VoiceOver biases its voice selection toward Spanish on the infinitive
///   and example, while the English base + audio button stay on the default
///   English voice. (macOS 14 does not expose `accessibilitySpeechLanguage`
///   to SwiftUI; the environment-locale path is the platform-compatible
///   substitute and is what HIG recommends for mixed-locale labels.)
/// - Dynamic Type: no hardcoded point sizes — everything is type-scaled.
/// - Esc keyboard shortcut on the primary CTA + a hidden duplicate so it works
///   regardless of focus location.
/// - v1.7.0 patch (Blocker 2): tap-outside-the-card also dismisses, because
///   spec FR-004 promised it and Marisol uses imprecise mouse-clicks. Card
///   content swallows taps so clicks ON it don't dismiss.
/// - v1.7.0 polish: visible Enter/Esc hint footer; both example lines use
///   rounded design (monospace on the Spanish line read as code/error).
struct VerbIntroCard: View {
    let intro: BackendClient.VerbIntro
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // v1.7.0 Blocker 2: invisible tap-outside surface. We can't use a
            // sheet/popover modifier here (RootView already owns the
            // navigation chrome around this view), so the dismiss-on-tap
            // gesture lives on a content-shaped Color.clear that fills the
            // available area. The card itself absorbs taps via its own
            // `.onTapGesture {}` no-op below, so clicks ON the card never
            // bubble up to this background.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }
                .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: 24) {
                    // Card header — light chip + section title.
                    VStack(spacing: 4) {
                        Text("CONOCE EL VERBO")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(2)
                            .environment(\.locale, Locale(identifier: "es-MX"))
                    }
                    .padding(.top, 24)

                    // Spanish infinitive — hero element. Large + rounded; matches
                    // ConjugationLessonView's prompt hero so the visual handoff to
                    // the question is continuous.
                    VStack(spacing: 6) {
                        Text(intro.es)
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.semibold)
                            .minimumScaleFactor(0.5)
                            .multilineTextAlignment(.center)
                            .environment(\.locale, Locale(identifier: "es-MX"))
                            .accessibilityAddTraits(.isHeader)
                        Text("español")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(1.5)
                    }

                    // English base + audio button. The button label already
                    // contains the word, so combining children keeps VoiceOver
                    // from reading "go, button, listen go" twice.
                    // v1.7.0 polish A: speaker gets the "S" keyboard shortcut
                    // matching LessonQuestionView/AnswerFeedbackView for muscle
                    // memory across surfaces.
                    HStack(spacing: 12) {
                        Text(intro.base)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.medium)
                        // F007 (v1.8.0). Dual-button prosody: normal "S" +
                        // slow "D" (tortuga) so Lucía's A1 learners can hear
                        // each phoneme before mimicking. Inline pair — the
                        // base is short enough that wrapping is rare.
                        SpeakButton(text: intro.base, shortcut: "s", label: "Escuchar", rate: .normal)
                        SpeakButton(text: intro.base, shortcut: "d", label: "Despacio", rate: .slow)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("English: \(intro.base)")

                    // Bilingual example. Spanish line above (filled, rounded),
                    // English below (rounded — keeping both in the same family
                    // so the Spanish line doesn't read as a code/terminal
                    // string to low-vision learners. The conjugation drill
                    // can still use monospace where the gap actually matters).
                    VStack(alignment: .leading, spacing: 6) {
                        Text(intro.exampleEsFilled)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .environment(\.locale, Locale(identifier: "es-MX"))
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(intro.exampleEn)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            // F007 (v1.8.0). Lucía: A1 learners need the
                            // full example modeled, not just the verb. The
                            // speaker pair sits inline with the English
                            // line so it's obvious which sentence plays.
                            // No shortcuts here — `s`/`d` are already
                            // claimed by the base-form pair above.
                            SpeakButton(
                                text: intro.exampleEn,
                                size: 14,
                                rate: .normal,
                                accessibilityLabelOverride: "Reproducir oración en inglés"
                            )
                            SpeakButton(
                                text: intro.exampleEn,
                                size: 14,
                                rate: .slow,
                                accessibilityLabelOverride: "Reproducir oración en inglés despacio"
                            )
                        }
                    }
                    // F011 (v1.12.0). Padding-literal sweep — 16pt → Spacing.md.
                    .padding(Spacing.md)
                    .frame(maxWidth: 540, alignment: .leading)
                    .background(
                        // F008 Item 2 (v1.9.0). Token sweep — 12pt radius → Radius.md.
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(.quaternary.opacity(0.5))
                    )
                    .accessibilityElement(children: .combine)

                    // Primary CTA. Esc shortcut + return key as the natural
                    // "continue" affordance.
                    Button(action: onDismiss) {
                        Text("Listo, vamos")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .environment(\.locale, Locale(identifier: "es-MX"))
                    .accessibilityHint("Continuar a la pregunta")

                    // v1.7.0 polish C: visible keyboard-shortcut hints. VO
                    // users get this info via standard shortcut announcement,
                    // so the footer is a11y-hidden to avoid redundant chatter.
                    Text("Enter para continuar · Esc para saltar")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)

                    // Invisible duplicate to capture Esc no matter where focus
                    // sits — SwiftUI macOS routes the .cancelAction shortcut to
                    // whichever visible Button declares it.
                    Button(action: onDismiss) { EmptyView() }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityHidden(true)
                        .frame(width: 0, height: 0)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                // v1.7.0 Blocker 2: card content absorbs taps so clicks ON
                // the card body don't bubble up to the dismiss-on-tap
                // background. The CTA button still receives its tap because
                // SwiftUI's button hit-testing precedes this no-op gesture.
                .contentShape(Rectangle())
                .onTapGesture { /* swallow */ }
            }
        }
    }
}
