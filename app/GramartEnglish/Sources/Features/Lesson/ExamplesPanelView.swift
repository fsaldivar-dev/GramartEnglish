import SwiftUI

struct ExamplesPanelView: View {
    @StateObject var viewModel: WordExamplesViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(viewModel.word)
                            .font(.title2.weight(.semibold))
                        SpeakButton(text: viewModel.word, size: 16)
                    }
                    Text("Ejemplos · \(viewModel.level)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Cerrar panel de ejemplos")
            }

            switch viewModel.state {
            case .idle, .loading:
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        ShimmerLine()
                    }
                }
                .padding(.vertical, 4)
                .accessibilityLabel("Loading examples")
            case .loaded(let examples, let fallback):
                if fallback {
                    FallbackBannerView()
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(examples.enumerated()), id: \.offset) { _, sentence in
                        HStack(alignment: .top, spacing: 8) {
                            Text(highlighted(sentence, word: viewModel.word))
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            SpeakButton(text: sentence, size: 14)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                attribution(fallback: fallback)
            case .failed(let message):
                Text(message)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 360, idealWidth: 420, minHeight: 280)
        .task { if case .idle = viewModel.state { await viewModel.load() } }
    }

    private func attribution(fallback: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: fallback ? "book" : "sparkles")
                .imageScale(.small)
            Text(fallback
                ? "Fuente: ejemplo curado del corpus local."
                : "Generado localmente con Ollama, basado en fuentes curadas."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func highlighted(_ sentence: String, word: String) -> AttributedString {
        var attr = AttributedString(sentence)
        let lower = sentence.lowercased()
        guard let range = lower.range(of: word.lowercased()) else { return attr }
        let start = lower.distance(from: lower.startIndex, to: range.lowerBound)
        let length = sentence.distance(from: range.lowerBound, to: range.upperBound)
        let chars = attr.characters
        guard start >= 0, start + length <= chars.count else { return attr }
        let attrStart = chars.index(chars.startIndex, offsetBy: start)
        let attrEnd = chars.index(attrStart, offsetBy: length)
        attr[attrStart..<attrEnd].font = .body.weight(.semibold)
        attr[attrStart..<attrEnd].foregroundColor = .accentColor
        return attr
    }
}

private struct ShimmerLine: View {
    @State private var shimmer = false
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .frame(height: 28)
            .opacity(shimmer ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: shimmer)
            .onAppear { shimmer = true }
    }
}
