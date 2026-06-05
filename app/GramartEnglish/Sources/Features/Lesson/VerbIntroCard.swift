import SwiftUI
import BackendClient

/// F006 (v1.7.0) — "Conoce el verbo" pre-conjugation micro-card.
///
/// Shown ONCE per `(macInstall, verbBase)` immediately before the first
/// `conjugate_pick_form` question for that verb. Dismissal paths (CTA, Esc)
/// route through the same `onDismiss` callback so the coordinator's
/// `markSeen + clear pendingIntro + advance` sequence is atomic at the call
/// site.
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
struct VerbIntroCard: View {
    let intro: BackendClient.VerbIntro
    let onDismiss: () -> Void

    var body: some View {
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
                HStack(spacing: 16) {
                    Text(intro.base)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.medium)
                    SpeakButton(text: intro.base, label: "Escuchar")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("English: \(intro.base)")

                // Bilingual example. Spanish line above, English below.
                // Mono-style for English to echo the question reveal pattern.
                VStack(alignment: .leading, spacing: 6) {
                    Text(intro.exampleEs)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .environment(\.locale, Locale(identifier: "es-MX"))
                    Text(intro.exampleEn)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .frame(maxWidth: 540, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
        }
    }
}
