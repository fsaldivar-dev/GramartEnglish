import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("GramartEnglish")
                // F008 Item 2 (v1.9.0). Token sweep — 40pt literal.
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .minimumScaleFactor(0.5)
                .accessibilityAddTraits(.isHeader)
            Text("Aprende vocabulario en inglés a tu nivel")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Label("Mini-test de 12 preguntas para estimar tu nivel.", systemImage: "checkmark.circle")
                Label("Todo se queda en tu Mac. Sin cuenta, sin telemetría.", systemImage: "lock.shield")
            }
            .font(.body)
            .frame(maxWidth: 460, alignment: .leading)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onStart) {
                    Text("Empezar el mini-test")
                        .frame(minWidth: 220)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button("Saltar y elegir nivel manualmente", action: onSkip)
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        // F011 (v1.12.0). Padding-literal sweep — 32pt → Spacing.xl.
        .padding(Spacing.xl)
    }
}
