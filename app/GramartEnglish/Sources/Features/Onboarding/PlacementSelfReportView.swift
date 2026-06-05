import SwiftUI
import BackendClient

/// F005 — Onboarding anchor. Asks the user a single question before the
/// adaptive placement begins, so a never-studied user doesn't waste their first
/// 5 items on C-level vocabulary. Skippable (defaults to no anchor →
/// algorithm starts at the midpoint estimate of 3.5).
struct PlacementSelfReportView: View {
    let onPick: (BackendClient.PlacementSelfReport?) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Text("Antes de empezar")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("¿Has estudiado inglés antes?")
                    // F008 Item 2 (v1.9.0). Token sweep — 34pt literal.
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Nos ayuda a calibrar el test. Puedes saltarlo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
                anchorButton(
                    index: 1,
                    label: "Nunca antes",
                    subtitle: "Empezamos por lo básico (A1)",
                    hint: "Te empezamos por palabras básicas, nivel A1",
                    selfReport: .never
                )
                anchorButton(
                    index: 2,
                    label: "Un poco / algunas clases",
                    subtitle: "Intermedio bajo (A2-B1)",
                    hint: "Empezamos con vocabulario intermedio bajo, A2 a B1",
                    selfReport: .some
                )
                anchorButton(
                    index: 3,
                    label: "Bastante, llevo años",
                    subtitle: "Intermedio alto (B1-B2)",
                    hint: "Empezamos con vocabulario intermedio alto, B1 a B2",
                    selfReport: .lots
                )
            }
            .frame(maxWidth: 540)

            // v1.4.1 F2: the skip button used to read as a plain text link
            // ("punishment" per user feedback). Promote it to a tinted
            // secondary button so it's clearly an equal-status option —
            // keyboardShortcut + a11y metadata are unchanged.
            Button(action: { onPick(nil) }) {
                Text("Empezar sin elegir")
                    .font(.callout)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut("0", modifiers: [])
            .accessibilityLabel("Empezar sin elegir nivel — tecla 0")
            .accessibilityHint("Salta esta pregunta y comienza el test sin anclaje")

            Spacer()
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pregunta inicial: ¿Has estudiado inglés antes?")
    }

    @ViewBuilder
    private func anchorButton(
        index: Int,
        label: String,
        subtitle: String,
        hint: String,
        selfReport: BackendClient.PlacementSelfReport
    ) -> some View {
        let keyLabel = String(index)
        Button(action: { onPick(selfReport) }) {
            HStack(spacing: 14) {
                Text(keyLabel)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 28, height: 28)
                    // F010 (v1.11.0). 6pt → Radius.sm (8).
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            // F010 (v1.11.0). 10pt → Radius.md (12).
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(keyLabel)), modifiers: [])
        .accessibilityLabel("Opción \(keyLabel): \(label). \(subtitle)")
        .accessibilityHint(hint)
    }
}
