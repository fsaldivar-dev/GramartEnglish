import SwiftUI
import BackendClient
import LessonKit

/// Per-mode mastery detail screen (T056).
///
/// MVP scope: shows the 4-mode badge strip + per-mode mastered/pending totals,
/// driven directly by `/v1/progress`. A future iteration will list the
/// individual words behind each mode (requires a new endpoint or a /v1/words
/// extension).
struct MyWordsView: View {
    let progress: BackendClient.ProgressResponse?
    let onClose: () -> Void

    private func badge(for mode: LessonMode) -> String {
        switch mode {
        case .readPickMeaning: return "📖"
        case .listenPickWord, .listenPickMeaning: return "👂"
        case .listenType: return "✏️"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text("Mis palabras")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle").imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Cerrar")
                }

                Text("Cada modo lleva su propia cuenta. Una palabra puede estar dominada en lectura y pendiente en listening — son dos habilidades distintas.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let p = progress {
                    VStack(spacing: 10) {
                        ForEach(SHIPPED_MODES, id: \.rawValue) { mode in
                            row(mode: mode, mastered: p.perModeMastered?[mode.rawValue] ?? 0)
                        }
                    }
                    .frame(maxWidth: 540)
                } else {
                    ProgressView("Cargando…")
                        .padding(.top, 40)
                }

                Spacer(minLength: 24)
            }
            .padding(24)
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    private func row(mode: LessonMode, mastered: Int) -> some View {
        HStack(spacing: 14) {
            Text(badge(for: mode))
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(.background.secondary, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName).font(.headline)
                Text(mode.displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(mastered)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text("dominadas").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.displayName): \(mastered) palabras dominadas")
    }
}
