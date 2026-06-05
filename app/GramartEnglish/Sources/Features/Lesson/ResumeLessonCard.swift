import SwiftUI

/// F010 Item 3 (v1.11.0). Priya's P1: when a learner finishes a lesson,
/// the summary screen needs a way to jump back to a *different*
/// in-flight lesson that the local snapshot still tracks. Without it,
/// the resume affordance only lived in HomeView and the "siguiente
/// lección" button silently swept a partially-completed lesson off
/// the user's attention path.
///
/// The card is dumb on purpose: it takes a totalCount + currentIndex
/// (already computed by the snapshot) and renders a single CTA. The
/// caller wires `onResume` into the RootFlowView phase transition.
struct ResumeLessonCard: View {
    let currentQuestionIndex: Int
    let totalCount: Int?
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.tint)
                    .imageScale(.large)
                    .accessibilityHidden(true)
                Text("Continuar lección anterior")
                    .font(.system(.headline, design: .rounded))
            }
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(action: onResume) {
                Text("Continuar")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .buttonStyle(.bordered)
            .accessibilityHint("Vuelve a la lección que dejaste a medias")
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: 540, alignment: .leading)
        .background(.tint.opacity(Tint.soft), in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continuar lección anterior. \(subtitle)")
    }

    /// Exposed (internal) for tests — pinning "Pregunta X de Y" vs
    /// "Pregunta X" rendering at the property level keeps the format
    /// from drifting into the view body.
    var subtitle: String {
        // Snapshot stores currentQuestionIndex (zero-based) but not the
        // lesson length on its own — when the server-side total is not
        // available (resume snapshot pre-load), fall back to a shorter
        // copy. The "X de Y" form is preferred whenever possible per
        // Priya — matches the resume banner in LessonFlowView.
        let oneBased = currentQuestionIndex + 1
        if let total = totalCount, total > 0 {
            return "Pregunta \(oneBased) de \(total)"
        }
        return "Pregunta \(oneBased)"
    }
}
