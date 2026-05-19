import SwiftUI
import BackendClient
import LessonKit

struct HomeView: View {
    let level: String
    let progress: BackendClient.ProgressResponse?
    let onStartLessonInMode: (LessonMode) -> Void
    let onResume: (String) -> Void
    let onOpenSettings: () -> Void
    let onOpenMyWords: () -> Void

    init(
        level: String,
        progress: BackendClient.ProgressResponse?,
        onStartLessonInMode: @escaping (LessonMode) -> Void,
        onResume: @escaping (String) -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenMyWords: @escaping () -> Void = {}
    ) {
        self.level = level
        self.progress = progress
        self.onStartLessonInMode = onStartLessonInMode
        self.onResume = onResume
        self.onOpenSettings = onOpenSettings
        self.onOpenMyWords = onOpenMyWords
    }

    private var levelPoolApprox: Int {
        // Rough heuristic: the corpus has ~50 words per CEFR level. We don't have
        // the exact figure here, but the card just needs a "pending" hint, not a
        // precise count. Backend exposes per-mode mastered; pending ≈ pool − mastered.
        // For the MVP corpus this is good enough; future work could surface the
        // exact level pool size in /v1/progress.
        50
    }

    private func pending(for mode: LessonMode) -> Int? {
        guard let mastered = progress?.perModeMastered?[mode.rawValue] else { return nil }
        return max(0, levelPoolApprox - mastered)
    }

    private var recommended: LessonMode? {
        guard let raw = progress?.recommendedMode else { return nil }
        return LessonMode(rawValue: raw)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                topBar
                levelBadge
                if let progress { statsRow(progress) }

                if let resumable = progress?.resumable {
                    resumableCard(resumable)
                }

                modeGrid

                if let last = progress?.lastLesson {
                    lastLessonCard(last)
                }

                Text("Tu progreso se queda en este Mac — sin cuenta, sin telemetría.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(32)
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Sub-views

    private var topBar: some View {
        HStack {
            Button(action: onOpenMyWords) {
                Label("Mis palabras", systemImage: "books.vertical")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            .accessibilityHint("Ver palabras dominadas por modo")
            Spacer()
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape").imageScale(.large)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityLabel("Ajustes")
        }
    }

    private var levelBadge: some View {
        HStack(spacing: 12) {
            Text(level)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.tint.opacity(0.18), in: Capsule())
                .foregroundStyle(.tint)
                .accessibilityLabel("Nivel actual \(level)")
            Text("Tu nivel actual").foregroundStyle(.secondary)
            Button("Cambiar", action: onOpenSettings)
                .buttonStyle(.borderless)
                .font(.caption)
                .accessibilityHint("Abre Ajustes para cambiar de nivel")
        }
    }

    private var modeGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(SHIPPED_MODES, id: \.rawValue) { mode in
                ModeCard(
                    mode: mode,
                    pendingCount: pending(for: mode),
                    isRecommended: mode == recommended,
                    action: { onStartLessonInMode(mode) }
                )
            }
            ForEach(ComingSoonMode.allCases, id: \.rawValue) { mode in
                ModeCard(comingSoon: mode)
            }
        }
        .frame(maxWidth: 560)
    }

    private func resumableCard(_ r: BackendClient.ProgressResponse.ResumableLesson) -> some View {
        Button(action: { onResume(r.lessonId) }) {
            VStack(spacing: 2) {
                Text("Continuar lección")
                Text("\(r.answeredCount) de \(r.totalCount) respondidas · \(r.level)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 540)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
    }

    private func statsRow(_ p: BackendClient.ProgressResponse) -> some View {
        HStack(spacing: 24) {
            stat("Dominadas", value: "\(p.masteredCount)")
            stat("Por repasar", value: "\(p.toReviewCount)")
            stat("Lecciones", value: "\(p.lessonsCompleted)")
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func lastLessonCard(_ last: BackendClient.ProgressResponse.LastLesson) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Última lección").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("\(last.score) / \(last.total)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Spacer()
                Text("\(last.level)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: 320)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Última lección: \(last.score) de \(last.total) en nivel \(last.level)")
    }
}
