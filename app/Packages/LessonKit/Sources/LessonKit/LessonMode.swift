import Foundation

public enum LessonMode: String, Codable, CaseIterable, Sendable, Equatable {
    case readPickMeaning = "read_pick_meaning"
    case listenPickWord = "listen_pick_word"
    case listenPickMeaning = "listen_pick_meaning"
    case listenType = "listen_type"
    case writePickWord = "write_pick_word"
    case writeTypeWord = "write_type_word"
    case writeFillGaps = "write_fill_gaps"  // v1.5: shipped — included in SHIPPED_MODES
    case conjugatePickForm = "conjugate_pick_form"  // v1.6 (F004 US1): shipped

    /// SF Symbol name suitable for `Image(systemName:)`.
    public var iconSystemName: String {
        switch self {
        case .readPickMeaning: return "book"
        case .listenPickWord, .listenPickMeaning, .listenType: return "ear"
        case .writePickWord, .writeTypeWord, .writeFillGaps: return "pencil"
        case .conjugatePickForm: return "arrow.triangle.2.circlepath"
        }
    }

    /// Short user-facing label in Spanish.
    public var displayName: String {
        switch self {
        case .readPickMeaning: return "Leer"
        case .listenPickWord, .listenPickMeaning, .listenType: return "Escuchar"
        case .writePickWord, .writeTypeWord, .writeFillGaps: return "Escribir"
        case .conjugatePickForm: return "Conjugar"
        }
    }

    /// Sub-label clarifying the variant in Spanish.
    public var displaySubtitle: String {
        switch self {
        case .readPickMeaning: return "Lee y elige el significado"
        case .listenPickWord: return "Escucha y elige la palabra"
        case .listenPickMeaning: return "Escucha y elige el significado"
        case .listenType: return "Escucha y escribe"
        case .writePickWord: return "Lee en español, elige la palabra en inglés"
        case .writeTypeWord: return "Lee en español, escribe la palabra en inglés"
        case .writeFillGaps: return "Lee en español, completa la palabra"
        case .conjugatePickForm: return "Lee el verbo en español, elige la forma en pasado"
        }
    }

    /// Audio auto-plays on question appear in these modes (FR-006).
    public var isListening: Bool {
        switch self {
        case .listenPickWord, .listenPickMeaning, .listenType: return true
        case .readPickMeaning, .writePickWord, .writeTypeWord, .writeFillGaps, .conjugatePickForm: return false
        }
    }

    /// Writing modes: Spanish prompt on screen, English is the answer (F003).
    /// NOTE: F004's `conjugatePickForm` is NOT a writing mode — it's its own
    /// productive axis (recall a *form* of a verb, not a vocab word). Track it
    /// via `isConjugation` instead.
    public var isWriting: Bool {
        switch self {
        case .writePickWord, .writeTypeWord, .writeFillGaps: return true
        default: return false
        }
    }

    /// Conjugation modes: Spanish verb infinitive → English form (F004).
    public var isConjugation: Bool {
        switch self {
        case .conjugatePickForm: return true
        default: return false
        }
    }

    /// Whether the user answers with a text field rather than option cards.
    public var isTyped: Bool {
        switch self {
        case .listenType, .writeTypeWord, .writeFillGaps: return true
        default: return false
        }
    }
}

/// Modes shipped in v1.6 (F004 US1 adds `conjugatePickForm`). The Home grid
/// renders one card per entry; `ComingSoonMode` covers anything not yet here.
public let SHIPPED_MODES: [LessonMode] = [
    .readPickMeaning,
    .listenPickWord,
    .listenPickMeaning,
    .listenType,
    .writePickWord,
    .writeTypeWord,
    .writeFillGaps,
    .conjugatePickForm,
]

/// A placeholder for Home cards that represent yet-unshipped modes. Raw
/// values are stable so they can become mastery rows when the feature ships.
///
/// v1.6.0: every prior coming-soon mode (`conjugatePickForm`) has shipped,
/// so this enum's `allCases` is effectively empty. We keep the type around
/// (rather than deleting it) so `HomeView`'s `ForEach(ComingSoonMode.allCases)`
/// keeps compiling and the next F004 sub-mode can re-populate it without a
/// callsite change.
///
/// Swift forbids enums with both a raw type and zero cases, so the next
/// shipped mode (F004 US2 `conjugate_type_form`) gets reserved here as a
/// stub and is gated out of `allCases` until it actually lands.
public enum ComingSoonMode: String, CaseIterable, Sendable {
    /// Reserved for F004 US2 — typed-input verb conjugation. Not yet shipped.
    /// `allCases` filters it out (see the override below) so HomeView and
    /// tests behave as if the enum had zero entries until US2 lands.
    case conjugateTypeForm = "conjugate_type_form"

    /// Stub — v1.6.0 keeps `allCases` empty because no coming-soon mode is
    /// actually surfaced. Re-include `.conjugateTypeForm` (and any future
    /// stubs) here when they're ready to render as disabled Home cards.
    public static var allCases: [ComingSoonMode] { [] }

    public var iconSystemName: String {
        switch self {
        case .conjugateTypeForm: return "pencil"
        }
    }

    public var displayName: String {
        switch self {
        case .conjugateTypeForm: return "Conjugar"
        }
    }

    public var displaySubtitle: String {
        switch self {
        case .conjugateTypeForm: return "Próximamente — escribe la forma en pasado"
        }
    }
}
