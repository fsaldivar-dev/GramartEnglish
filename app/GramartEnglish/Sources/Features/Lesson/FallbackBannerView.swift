import SwiftUI

struct FallbackBannerView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                // F010 (v1.11.0). Raw `.orange` → Semantic.warning so the
                // banner glyph stays paired with the v1.10 dark-tuned amber.
                .foregroundStyle(Semantic.warning)
            Text("Ejemplos con IA no disponibles. Mostrando un ejemplo curado.")
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // F008 Item 2 (v1.9.0). Token sweep — 8pt radius → Radius.sm.
        .background(Semantic.warning.opacity(Tint.soft), in: RoundedRectangle(cornerRadius: Radius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ejemplos con IA no disponibles. Mostrando ejemplo curado.")
    }
}
