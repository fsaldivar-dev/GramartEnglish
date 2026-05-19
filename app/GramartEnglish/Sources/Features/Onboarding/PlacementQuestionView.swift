import SwiftUI
import BackendClient

struct PlacementQuestionView: View {
    let question: BackendClient.PlacementQuestion
    let progress: (current: Int, total: Int)
    let onAnswer: (Int) -> Void

    private var hasSentence: Bool { !(question.sentence?.isEmpty ?? true) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ProgressHeader(current: progress.current, total: progress.total)

                if hasSentence {
                    sentenceCard
                } else {
                    bareWordCard
                }

                Text(hasSentence
                     ? "¿Qué significa la palabra resaltada?"
                     : "¿Qué significa esta palabra?")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        OptionCard(index: index, text: option, action: { onAnswer(index) })
                    }
                    Button(action: { onAnswer(-1) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                            Text("No lo sé")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("0", modifiers: [])
                    .accessibilityLabel("No lo sé")
                }
                .frame(maxWidth: 540)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pregunta \(progress.current) de \(progress.total)")
        .onAppear { autoSpeak() }
        .onChange(of: question.id) { _, _ in autoSpeak() }
    }

    private var sentenceCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(highlightedSentence)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 540)
                SpeakButton(text: question.sentence ?? "", shortcut: "s", size: 18)
            }
            Text(question.word.lowercased())
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.12), in: Capsule())
                .accessibilityLabel("Palabra objetivo: \(question.word)")
        }
    }

    private var bareWordCard: some View {
        HStack(spacing: 8) {
            Text(question.word)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .accessibilityAddTraits(.isHeader)
            SpeakButton(text: question.word, shortcut: "s", size: 20)
        }
    }

    private var highlightedSentence: AttributedString {
        guard let sentence = question.sentence, !sentence.isEmpty else { return AttributedString("") }
        var attr = AttributedString(sentence)
        let lower = sentence.lowercased()
        let word = question.word.lowercased()
        if let range = lower.range(of: word) {
            let start = lower.distance(from: lower.startIndex, to: range.lowerBound)
            let length = sentence.distance(from: range.lowerBound, to: range.upperBound)
            let chars = attr.characters
            guard start >= 0, start + length <= chars.count else { return attr }
            let attrStart = chars.index(chars.startIndex, offsetBy: start)
            let attrEnd = chars.index(attrStart, offsetBy: length)
            attr[attrStart..<attrEnd].font = .system(size: 24, weight: .bold, design: .rounded)
            attr[attrStart..<attrEnd].foregroundColor = .accentColor
        }
        return attr
    }

    private func autoSpeak() {
        // Speak the sentence (or the word if no sentence) when the question appears.
        if let s = question.sentence, !s.isEmpty {
            SpeechService.shared.speakEnglish(s)
        } else {
            SpeechService.shared.speakEnglish(question.word)
        }
    }
}

struct ProgressHeader: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("Pregunta \(current) de \(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(current), total: Double(total))
                .progressViewStyle(.linear)
                .frame(maxWidth: 540)
        }
    }
}

struct OptionCard: View {
    let index: Int
    let text: String
    let action: () -> Void

    private var keyLabel: String { String(index + 1) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(keyLabel)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 28, height: 28)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                Text(text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(keyLabel)), modifiers: [])
        .accessibilityLabel("Opción \(keyLabel): \(text)")
        .accessibilityHint("Presiona \(keyLabel) para elegir")
    }
}
