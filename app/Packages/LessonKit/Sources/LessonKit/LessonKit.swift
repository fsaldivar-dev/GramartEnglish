import Foundation

public enum LessonKit {
    public static let version = "1.0.0"
}

public struct LessonQuestion: Equatable, Sendable, Identifiable {
    public let id: String
    public let word: String
    public let options: [String]
    public let position: Int

    public init(id: String, word: String, options: [String], position: Int) {
        self.id = id
        self.word = word
        self.options = options
        self.position = position
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

    public init(
        questionId: String,
        chosenIndex: Int?,
        kind: AnswerKind,
        correctIndex: Int,
        correctOption: String,
        canonicalDefinition: String
    ) {
        self.questionId = questionId
        self.chosenIndex = chosenIndex
        self.kind = kind
        self.correctIndex = correctIndex
        self.correctOption = correctOption
        self.canonicalDefinition = canonicalDefinition
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
