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
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
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

            Button(action: { onPick(nil) }) {
                Text("Empezar sin elegir")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
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
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
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
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(keyLabel)), modifiers: [])
        .accessibilityLabel("Opción \(keyLabel): \(label). \(subtitle)")
        .accessibilityHint(hint)
    }
}
