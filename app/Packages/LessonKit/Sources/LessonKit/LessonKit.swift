import Foundation

public enum LessonKit {
    public static let version = "1.0.0"
}

public struct LessonQuestion: Equatable, Sendable, Identifiable {
    public let id: String
    public let word: String
    public let options: [String]
    public let position: Int
    /// v1.3+. Spanish meaning the client should render as the question
    /// stimulus for write modes (`write_pick_word`, `write_type_word`,
    /// `write_fill_gaps`). `nil` for read + listen modes — those keep
    /// rendering `word` as before.
    public let prompt: String?
    /// v1.5+. Scaffolded English word with underscores marking the letters
    /// the user must type. Populated only for `write_fill_gaps` questions
    /// where the target word is long enough (server auto-promotes shorter
    /// words to plain typed input and omits this field).
    public let maskedWord: String?
    /// v1.6+. Populated only for `conjugate_pick_form` — English base form
    /// of the verb being conjugated (e.g. "go" when the answer is "went").
    public let verbBase: String?
    /// v1.6+. Populated only for `conjugate_pick_form`. v1.6.0 ships
    /// `"simple_past"`. Stored as a raw string so future tenses don't force
    /// a LessonKit ABI bump.
    public let targetTense: String?
    /// v1.6.0 patch (Blocker 2). Populated only for `conjugate_pick_form` —
    /// Spanish example sentence with `___` marking the verb slot (e.g.
    /// "Ayer ___ tacos."). Disambiguates Spanish preterite vs imperfect
    /// for verbs whose English past is the same form. Shown beneath the
    /// "Pasado simple de …" header in a secondary style.
    public let exampleEs: String?
    /// v1.6.0 patch (Blocker 2). Populated only for `conjugate_pick_form` —
    /// English translation with the verb already conjugated. Revealed
    /// after the user answers, never before.
    public let exampleEn: String?
    /// F008 Item 3 (v1.9.0). Optional Spanish false-friend warning. When
    /// the target word has a high-frequency Spanish look-alike with a
    /// different meaning, the server attaches a short "OJO: no es '…'"
    /// string here. The client renders it in the post-answer feedback
    /// panel so the disambiguation lands at the moment of recall, not as
    /// a preemptive hint. `nil` for the ~98% of words without a belt entry.
    public let falseFriendEs: String?

    public init(
        id: String,
        word: String,
        options: [String],
        position: Int,
        prompt: String? = nil,
        maskedWord: String? = nil,
        verbBase: String? = nil,
        targetTense: String? = nil,
        exampleEs: String? = nil,
        exampleEn: String? = nil,
        falseFriendEs: String? = nil
    ) {
        self.id = id
        self.word = word
        self.options = options
        self.position = position
        self.prompt = prompt
        self.maskedWord = maskedWord
        self.verbBase = verbBase
        self.targetTense = targetTense
        self.exampleEs = exampleEs
        self.exampleEn = exampleEn
        self.falseFriendEs = falseFriendEs
    }
}

public enum AnswerKind: String, Equatable, Sendable {
    case correct, incorrect, skipped
}

public struct AnswerOutcome: Equatable, Sendable {
    public let questionId: String
    public let chosenIndex: Int?
    public let kind: AnswerKind
    public let correctIndex: Int
    public let correctOption: String
    public let canonicalDefinition: String
    /// F007 (v1.8.0). Optional teaching string supplied by the backend when
    /// the learner committed to a recognisable error pattern (currently:
    /// over-regularized past form of an irregular verb). The client renders
    /// it under the wrong-answer banner in `AnswerFeedbackView`. `nil` for
    /// correct answers and for any non-targeted error pattern.
    public let feedbackHint: String?

    public init(
        questionId: String,
        chosenIndex: Int?,
        kind: AnswerKind,
        correctIndex: Int,
        correctOption: String,
        canonicalDefinition: String,
        feedbackHint: String? = nil
    ) {
        self.questionId = questionId
        self.chosenIndex = chosenIndex
        self.kind = kind
        self.correctIndex = correctIndex
        self.correctOption = correctOption
        self.canonicalDefinition = canonicalDefinition
        self.feedbackHint = feedbackHint
    }

    public var correct: Bool { kind == .correct }
}

public struct LessonState: Equatable, Sendable {
    public let lessonId: String
    public let questions: [LessonQuestion]
    public private(set) var currentIndex: Int
    public private(set) var outcomes: [AnswerOutcome]

    public init(lessonId: String, questions: [LessonQuestion]) {
        self.lessonId = lessonId
        self.questions = questions
        self.currentIndex = 0
        self.outcomes = []
    }

    public var currentQuestion: LessonQuestion? {
        currentIndex < questions.count ? questions[currentIndex] : nil
    }

    public var isComplete: Bool {
        outcomes.count >= questions.count
    }

    public var progress: (current: Int, total: Int) {
        (min(currentIndex + 1, questions.count), questions.count)
    }

    public var score: Int {
        outcomes.filter { $0.correct }.count
    }

    public mutating func recordOutcome(_ outcome: AnswerOutcome) {
        outcomes.append(outcome)
    }

    public mutating func advance() {
        if currentIndex < questions.count { currentIndex += 1 }
    }
}
