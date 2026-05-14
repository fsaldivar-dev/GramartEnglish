import SwiftUI
import LessonKit

/// One tile in the Home 2×2 mode grid (FR-009/FR-010/FR-011).
///
/// Shows an SF Symbol icon, a Spanish title + subtitle, a "Pendientes: N"
/// counter, and (optionally) a "Recomendado para ti" tag. Disabled or
/// `comingSoon` cards render at reduced opacity with a "Próximamente" pill
/// and ignore taps.
struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let pendingCount: Int?
    let isEnabled: Bool
    let comingSoon: Bool
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if isEnabled && !comingSoon { action() } }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Spacer()
                    if comingSoon {
                        Text("Próximamente")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Próximamente — no disponible")
                    } else if isRecommended {
                        Text("Recomendado para ti")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.tint.opacity(0.18), in: Capsule())
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Recomendado para ti")
                    }
                }

                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if let pendingCount, !comingSoon {
                    Text("Pendientes: \(pendingCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(pendingCount) palabras por dominar")
                } else if comingSoon {
                    Text("Llega en una próxima versión")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isRecommended && !comingSoon ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1.5)
            )
            .opacity(comingSoon || !isEnabled ? 0.5 : 1.0)
            .grayscale(comingSoon ? 0.7 : 0.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || comingSoon)
        .help(comingSoon ? "Estará disponible en una próxima versión" : subtitle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isEnabled && !comingSoon ? .isButton : [])
    }

    private var accessibilityLabel: String {
        var parts: [String] = [title]
        parts.append(subtitle)
        if comingSoon { parts.append("Próximamente — no disponible") }
        else if isRecommended { parts.append("Recomendado para ti") }
        if let pendingCount, !comingSoon { parts.append("\(pendingCount) palabras por dominar") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Convenience initializers from LessonMode / ComingSoonMode

extension ModeCard {
    init(mode: LessonMode, pendingCount: Int?, isRecommended: Bool, action: @escaping () -> Void) {
        self.init(
            icon: mode.iconSystemName,
            title: mode.displayName,
            subtitle: mode.displaySubtitle,
            pendingCount: pendingCount,
            isEnabled: true,
            comingSoon: false,
            isRecommended: isRecommended,
            action: action
        )
    }

    init(comingSoon mode: ComingSoonMode) {
        self.init(
            icon: mode.iconSystemName,
            title: mode.displayName,
            subtitle: mode.displaySubtitle,
            pendingCount: nil,
            isEnabled: false,
            comingSoon: true,
            isRecommended: false,
            action: {}
        )
    }
}
