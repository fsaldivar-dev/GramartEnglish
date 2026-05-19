import Foundation

public enum LessonMode: String, Codable, CaseIterable, Sendable, Equatable {
    case readPickMeaning = "read_pick_meaning"
    case listenPickWord = "listen_pick_word"
    case listenPickMeaning = "listen_pick_meaning"
    case listenType = "listen_type"
    case writePickWord = "write_pick_word"
    case writeTypeWord = "write_type_word"
    case writeFillGaps = "write_fill_gaps"  // v1.4 placeholder; excluded from SHIPPED_MODES

    /// SF Symbol name suitable for `Image(systemName:)`.
    public var iconSystemName: String {
        switch self {
        case .readPickMeaning: return "book"
        case .listenPickWord, .listenPickMeaning, .listenType: return "ear"
        case .writePickWord, .writeTypeWord, .writeFillGaps: return "pencil"
        }
    }

    /// Short user-facing label in Spanish.
    public var displayName: String {
        switch self {
        case .readPickMeaning: return "Leer"
        case .listenPickWord, .listenPickMeaning, .listenType: return "Escuchar"
        case .writePickWord, .writeTypeWord, .writeFillGaps: return "Escribir"
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
        }
    }

    /// Audio auto-plays on question appear in these modes (FR-006).
    public var isListening: Bool {
        switch self {
        case .listenPickWord, .listenPickMeaning, .listenType: return true
        case .readPickMeaning, .writePickWord, .writeTypeWord, .writeFillGaps: return false
        }
    }

    /// Writing modes: Spanish prompt on screen, English is the answer (F003).
    public var isWriting: Bool {
        switch self {
        case .writePickWord, .writeTypeWord, .writeFillGaps: return true
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

/// Modes shipped in v1.3. `writeFillGaps` ships in v1.4.
public let SHIPPED_MODES: [LessonMode] = [
    .readPickMeaning,
    .listenPickWord,
    .listenPickMeaning,
    .listenType,
    .writePickWord,
    .writeTypeWord,
]

/// A placeholder for Home cards that represent yet-unshipped modes. Raw
/// values are stable so they can become mastery rows when the feature ships.
public enum ComingSoonMode: String, CaseIterable, Sendable {
    case writeFillGaps = "write_fill_gaps"
    case conjugatePickForm = "conjugate_pick_form"

    public var iconSystemName: String {
        switch self {
        case .writeFillGaps: return "pencil"
        case .conjugatePickForm: return "arrow.triangle.2.circlepath"
        }
    }

    public var displayName: String {
        switch self {
        case .writeFillGaps: return "Escribir"
        case .conjugatePickForm: return "Conjugar"
        }
    }

    public var displaySubtitle: String {
        switch self {
        case .writeFillGaps: return "Próximamente — completa la palabra con letras faltantes"
        case .conjugatePickForm: return "Próximamente — conjuga verbos en distintos tiempos"
        }
    }
}
