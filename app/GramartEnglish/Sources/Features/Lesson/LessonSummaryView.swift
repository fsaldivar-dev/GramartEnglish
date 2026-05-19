import SwiftUI
import BackendClient
import LessonKit

struct LessonSummaryView: View {
    let summary: BackendClient.LessonSummaryResponse
    let mode: LessonMode
    let perModeMastered: [String: Int]?
    let onStartAnother: () -> Void
    let onBackHome: () -> Void

    init(
        summary: BackendClient.LessonSummaryResponse,
        mode: LessonMode = .readPickMeaning,
        perModeMastered: [String: Int]? = nil,
        onStartAnother: @escaping () -> Void,
        onBackHome: @escaping () -> Void
    ) {
        self.summary = summary
        self.mode = mode
        self.perModeMastered = perModeMastered
        self.onStartAnother = onStartAnother
        self.onBackHome = onBackHome
    }

    private func badge(for mode: LessonMode) -> String {
        switch mode {
        case .readPickMeaning: return "📖"
        case .listenPickWord, .listenPickMeaning: return "👂"
        case .listenType: return "✏️"
        }
    }

    private var tone: String {
        if summary.score >= 8 { return "¡Excelente trabajo!" }
        if summary.score >= 5 { return "Buena práctica" }
        return "Sigue así — estas palabras son difíciles"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("\(summary.score) / \(summary.total)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Puntuación: \(summary.score) de \(summary.total)")
                Text(tone)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                summaryStat("Correctas", value: summary.score, color: .green, icon: "checkmark.circle.fill")
                if summary.skipped > 0 {
                    summaryStat("No sabía", value: summary.skipped, color: .orange, icon: "questionmark.circle.fill")
                }
                if summary.wrong > 0 {
                    summaryStat("Erradas", value: summary.wrong, color: .red, icon: "xmark.circle.fill")
                }
            }
            .padding(.vertical, 4)

            if let counts = perModeMastered {
                perModeBadgeStrip(counts: counts)
            }

            if !summary.missedWords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Palabras por repasar")
                        .font(.headline)
                    ForEach(summary.missedWords) { missed in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: missed.outcome == .skipped ? "questionmark.circle" : "xmark.circle")
                                .foregroundStyle(missed.outcome == .skipped ? Color.orange : Color.red)
                                .imageScale(.small)
                            Text(missed.word)
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .frame(minWidth: 100, alignment: .leading)
                            Text(missed.canonicalDefinition)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxWidth: 540)
            }

            Spacer()

            VStack(spacing: 12) {
                Button("Empezar otra lección", action: onStartAnother)
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                Button("Volver al inicio", action: onBackHome)
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(32)
    }

    private func perModeBadgeStrip(counts: [String: Int]) -> some View {
        let modes: [LessonMode] = SHIPPED_MODES
        return VStack(alignment: .leading, spacing: 6) {
            Text("Palabras dominadas por modo")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                ForEach(modes, id: \.rawValue) { m in
                    let count = counts[m.rawValue] ?? 0
                    let isCurrent = m == mode
                    HStack(spacing: 6) {
                        Text(badge(for: m)).font(.title3)
                        Text("\(count)")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (isCurrent ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule().strokeBorder(isCurrent ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(m.displayName): \(count) palabras dominadas")
                }
            }
        }
        .frame(maxWidth: 540, alignment: .leading)
    }

    private func summaryStat(_ label: String, value: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text("\(value)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
