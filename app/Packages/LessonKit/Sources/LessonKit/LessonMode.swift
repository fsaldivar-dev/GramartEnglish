import Foundation

public enum LessonMode: String, Codable, CaseIterable, Sendable, Equatable {
    case readPickMeaning = "read_pick_meaning"
    case listenPickWord = "listen_pick_word"
    case listenPickMeaning = "listen_pick_meaning"
    case listenType = "listen_type"

    /// SF Symbol name suitable for `Image(systemName:)`.
    public var iconSystemName: String {
        switch self {
        case .readPickMeaning: return "book"
        case .listenPickWord, .listenPickMeaning, .listenType: return "ear"
        }
    }

    /// Short user-facing label in Spanish.
    public var displayName: String {
        switch self {
        case .readPickMeaning: return "Leer"
        case .listenPickWord, .listenPickMeaning, .listenType: return "Escuchar"
        }
    }

    /// Sub-label clarifying the variant in Spanish.
    public var displaySubtitle: String {
        switch self {
        case .readPickMeaning: return "Lee y elige el significado"
        case .listenPickWord: return "Escucha y elige la palabra"
        case .listenPickMeaning: return "Escucha y elige el significado"
        case .listenType: return "Escucha y escribe"
        }
    }

    /// Audio auto-plays on question appear in these modes (FR-006).
    public var isListening: Bool {
        switch self {
        case .listenPickWord, .listenPickMeaning, .listenType: return true
        case .readPickMeaning: return false
        }
    }

    /// Whether the user answers with a text field rather than option cards.
    public var isTyped: Bool { self == .listenType }
}

/// Modes that are shipped in this feature. `LessonMode.allCases` may include
/// coming-soon modes (e.g., write_*, conjugate_*) once F003/F004 add them.
public let SHIPPED_MODES: [LessonMode] = LessonMode.allCases

/// A placeholder for cards on Home that represent future features. The raw
/// value is stable so it can be stored in mastery rows once the feature ships.
public enum ComingSoonMode: String, CaseIterable, Sendable {
    case writePickWord = "write_pick_word"
    case writeTypeWord = "write_type_word"
    case conjugatePickForm = "conjugate_pick_form"

    public var iconSystemName: String {
        switch self {
        case .writePickWord, .writeTypeWord: return "pencil"
        case .conjugatePickForm: return "arrow.triangle.2.circlepath"
        }
    }

    public var displayName: String {
        switch self {
        case .writePickWord, .writeTypeWord: return "Escribir"
        case .conjugatePickForm: return "Conjugar"
        }
    }

    public var displaySubtitle: String {
        switch self {
        case .writePickWord, .writeTypeWord: return "Próximamente — escribe la palabra en inglés"
        case .conjugatePickForm: return "Próximamente — conjuga verbos en distintos tiempos"
        }
    }
}
