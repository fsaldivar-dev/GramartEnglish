import SwiftUI

struct FallbackBannerView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.orange)
            Text("Ejemplos con IA no disponibles. Mostrando un ejemplo curado.")
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ejemplos con IA no disponibles. Mostrando ejemplo curado.")
    }
}
