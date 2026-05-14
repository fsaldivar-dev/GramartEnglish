import SwiftUI

/// Typed-answer input for `listen_type` mode (FR-007).
///
/// Plain SwiftUI `TextField`. Auto-focus is attempted best-effort via
/// `@FocusState` after a short delay; if the OS doesn't honor it (a known
/// macOS quirk inside `ScrollView`), the user can just click the field —
/// standard macOS UX. The submit/skip/hint behavior is the same either way.
struct TypedAnswerInputView: View {
    let questionId: String
    let canonical: String
    let onSubmit: (String) -> Void
    let onSkip: () -> Void

    @State private var text: String = ""
    @State private var hintChars: Int = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            TextField("escribe la palabra…", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 22, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .onSubmit(submit)
                .task(id: questionId) {
                    // Reset on new question + best-effort focus. Wrapped in
                    // `.task(id:)` so it runs AFTER the view is in a window
                    // (rather than `.onAppear` which fires too early on macOS).
                    text = ""
                    hintChars = 0
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    isFocused = true
                }.onTapGesture {
                    isFocused = true
                    print("chante text")
                }

            if hintChars > 0 {
                Text("Pista: " + String(canonical.prefix(hintChars)) + String(repeating: "•", count: max(0, canonical.count - hintChars)))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Pista: primeras \(hintChars) letras")
            }

            HStack(spacing: 12) {
                Button(action: revealNextHint) {
                    Label("Pista (⌘H)", systemImage: "lightbulb")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("h", modifiers: .command)
                .disabled(hintChars >= canonical.count)
                .accessibilityHint("Revela una letra más de la palabra")

                Button(action: submit) {
                    Text("Enviar")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(action: onSkip) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                        Text("No lo sé (⌘.)")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(".", modifiers: .command)
                .accessibilityLabel("No lo sé — revelar respuesta")
            }
        }
        .padding(.bottom, 16)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            onSkip()
        } else {
            onSubmit(trimmed)
        }
    }

    private func revealNextHint() {
        if hintChars < canonical.count { hintChars += 1 }
    }
}
