import SwiftUI

/// F011 Item 3 (v1.12.0). Priya's keyboard cheatsheet — a lightweight,
/// always-reachable reminder of every shortcut shipping today.
///
/// Background: F002–F010 layered shortcut after shortcut (`S`/`D` for audio
/// speed, `1`–`4` for options, `⌘H` for hints, `⌘,` for Settings) without
/// ever surfacing the full list in-app. Priya's v1.11 review flagged that
/// power users who learn one shortcut can't discover the rest — they have
/// to read the repo README.
///
/// Trigger: ⌘`/` from anywhere (RootView attaches the global shortcut to a
/// hidden button that toggles a sheet). Escape closes (the sheet inherits
/// the standard sheet-dismissal behaviour).
///
/// Spanish primary — same audience as the lesson copy. Each row is a
/// monospaced key (so the visual rhythm reads like a keyboard, not prose)
/// followed by a Spanish action description.
///
/// VoiceOver: each row is announced as `"<key>, <action>"` via
/// `accessibilityElement(children: .combine)` + an explicit label, so the
/// rotor sees one row per shortcut and the screen reader doesn't read the
/// key glyph and the prose as separate utterances.
struct ShortcutsCheatsheetView: View {

    /// One row of the cheatsheet. Surfaced as a type (not a tuple) so the
    /// test target can pin the full list against a known-good snapshot
    /// without driving the SwiftUI body.
    struct Entry: Equatable {
        let key: String
        let action: String
    }

    /// Audio shortcuts — Mariana's listening modes (F002) introduced `S` /
    /// `D` for normal / slow playback; `⌘M` is the global mute toggle from
    /// F004.
    static let audioEntries: [Entry] = [
        Entry(key: "S",  action: "Escuchar (velocidad normal)"),
        Entry(key: "D",  action: "Escuchar (despacio)"),
        Entry(key: "⌘M", action: "Silenciar / activar audio"),
    ]

    /// Answer shortcuts — `1`–`4` map to options across every multi-choice
    /// mode; `0` is the self-report "no lo sé" anchor; `Enter` commits
    /// typed answers (F003 write modes); `⌘H` requests the hint Lucía
    /// shipped in v1.10 for the writeFillGaps mode.
    static let answerEntries: [Entry] = [
        Entry(key: "1–4",  action: "Elegir opción"),
        Entry(key: "0",    action: "No lo sé"),
        Entry(key: "Enter", action: "Enviar respuesta"),
        Entry(key: "⌘H",   action: "Pedir pista"),
    ]

    /// Navigation shortcuts — `Esc` closes the active sheet (cheatsheet,
    /// Settings, Examples panel); `⌘/` toggles this view from anywhere.
    static let navigationEntries: [Entry] = [
        Entry(key: "Esc", action: "Cerrar / salir"),
        Entry(key: "⌘/",  action: "Mostrar este menú"),
    ]

    /// Concatenated list used by `ShortcutsCheatsheetTests` to pin that no
    /// section accidentally loses an entry across refactors. Keep this
    /// computed property out of the body so the SwiftUI graph doesn't
    /// re-build it on every render.
    static var allEntries: [Entry] {
        audioEntries + answerEntries + navigationEntries
    }

    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Atajos de teclado")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            section(title: "Audio", entries: Self.audioEntries)
            section(title: "Respuesta", entries: Self.answerEntries)
            section(title: "Navegación", entries: Self.navigationEntries)

            HStack {
                Spacer()
                Button("Cerrar (Esc)", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(Spacing.xl)
        .frame(minWidth: 360, idealWidth: 420)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Atajos de teclado")
    }

    @ViewBuilder
    private func section(title: String, entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(entries, id: \.key) { entry in
                row(entry)
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: Entry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(entry.key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .frame(minWidth: 56, alignment: .leading)
                .padding(.vertical, Spacing.xxs)
                .padding(.horizontal, Spacing.xs)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.sm))
            Text(entry.action)
                .font(.body)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.key), \(entry.action)")
    }
}
