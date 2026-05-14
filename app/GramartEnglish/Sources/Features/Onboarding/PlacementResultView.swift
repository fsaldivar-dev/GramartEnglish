import SwiftUI
import BackendClient

struct PlacementResultView: View {
    let result: BackendClient.PlacementResultResponse
    let onAccept: () -> Void
    let onPickAnother: () -> Void

    private static let levelDescriptions: [String: String] = [
        "A1": "Principiante — palabras de uso diario.",
        "A2": "Elemental — conversaciones simples.",
        "B1": "Intermedio — la mayoría de temas cotidianos.",
        "B2": "Intermedio alto — temas abstractos, expresión matizada.",
        "C1": "Avanzado — fluidez y detalle.",
        "C2": "Proficiente — dominio casi nativo.",
    ]
    private static let levelOrder: [String] = ["A1", "A2", "B1", "B2", "C1", "C2"]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Tu nivel estimado")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(result.estimatedLevel)
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .accessibilityAddTraits(.isHeader)

            Text(Self.levelDescriptions[result.estimatedLevel] ?? "")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                ForEach(Self.levelOrder, id: \.self) { lvl in
                    let score = result.perLevelScores[lvl]
                    let correct = score?.correct ?? 0
                    let attempted = score?.attempted ?? 0
                    HStack {
                        Text(lvl).font(.system(.body, design: .monospaced)).frame(width: 32, alignment: .leading)
                        ProgressView(value: attempted > 0 ? Double(correct) / Double(attempted) : 0)
                            .progressViewStyle(.linear)
                            .tint(lvl == result.estimatedLevel ? .accentColor : .secondary)
                        Text("\(correct)/\(attempted)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityLabel("Nivel \(lvl): \(correct) correctas de \(attempted)")
                }
            }
            .frame(maxWidth: 360)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button("Empezar mi primera lección", action: onAccept)
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                Button("Elegir otro nivel", action: onPickAnother)
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(32)
    }
}
