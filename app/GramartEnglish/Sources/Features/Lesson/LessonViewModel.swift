import Foundation
import BackendClient
import LessonKit

@MainActor
public final class LessonViewModel: ObservableObject {

    public enum Phase: Equatable {
        case idle
        case loading
        case answering(LessonState)
        case revealing(LessonState, AnswerOutcome)
        case completing(LessonState)
        case summary(BackendClient.LessonSummaryResponse)
        case failed(String)
    }

    @Published public private(set) var phase: Phase = .idle
    public let mode: LessonMode
    private let client: BackendClient
    private let level: String
    private var questionShownAt: Date = .now
    private var lastTypedEcho: String?

    public init(client: BackendClient, level: String, mode: LessonMode = .readPickMeaning) {
        self.client = client
        self.level = level
        self.mode = mode
    }

    public func start() async {
        phase = .loading
        do {
            let response = try await client.startLesson(level: level, mode: mode.rawValue)
            let questions = response.questions.map { q in
                LessonQuestion(id: q.id, word: q.word, options: q.options, position: q.position)
            }
            let state = LessonState(lessonId: response.lessonId, questions: questions)
            questionShownAt = .now
            phase = .answering(state)
        } catch {
            phase = .failed(Self.describe(error))
        }
    }

    public func answer(_ optionIndex: Int) async {
        guard case .answering(let state) = phase, let question = state.currentQuestion else { return }
        let elapsedMs = Int(Date().timeIntervalSince(questionShownAt) * 1000)
        do {
            let response = try await client.answerLesson(
                lessonId: state.lessonId,
                questionId: question.id,
                optionIndex: optionIndex,
                answerMs: elapsedMs
            )
            let outcome = AnswerOutcome(
                questionId: question.id,
                chosenIndex: optionIndex,
                kind: AnswerKind(rawValue: response.outcome.rawValue) ?? .incorrect,
                correctIndex: response.correctIndex,
                correctOption: response.correctOption,
                canonicalDefinition: response.canonicalDefinition
            )
            var updated = state
            updated.recordOutcome(outcome)
            lastTypedEcho = nil
            phase = .revealing(updated, outcome)
        } catch {
            phase = .failed(Self.describe(error))
        }
    }

    /// Submit a typed answer (listen_type mode). Empty input is treated as skip.
    public func answerTyped(_ text: String) async {
        guard case .answering(let state) = phase, let question = state.currentQuestion else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            await skip()
            return
        }
        let elapsedMs = Int(Date().timeIntervalSince(questionShownAt) * 1000)
        do {
            let response = try await client.answerLesson(
                lessonId: state.lessonId,
                questionId: question.id,
                typedAnswer: trimmed,
                answerMs: elapsedMs
            )
            let outcome = AnswerOutcome(
                questionId: question.id,
                chosenIndex: nil,
                kind: AnswerKind(rawValue: response.outcome.rawValue) ?? .incorrect,
                correctIndex: response.correctIndex,
                correctOption: response.correctOption,
                canonicalDefinition: response.canonicalDefinition
            )
            var updated = state
            updated.recordOutcome(outcome)
            lastTypedEcho = response.typedAnswerEcho
            phase = .revealing(updated, outcome)
        } catch {
            phase = .failed(Self.describe(error))
        }
    }

    /// The echo of the user's typed answer for the question currently being revealed,
    /// or `nil` if the current question was answered via options/skip.
    public var typedEchoForReveal: String? { lastTypedEcho }

    public func skip() async {
        guard case .answering(let state) = phase, let question = state.currentQuestion else { return }
        let elapsedMs = Int(Date().timeIntervalSince(questionShownAt) * 1000)
        do {
            let response = try await client.skipLesson(
                lessonId: state.lessonId,
                questionId: question.id,
                answerMs: elapsedMs
            )
            let outcome = AnswerOutcome(
                questionId: question.id,
                chosenIndex: nil,
                kind: .skipped,
                correctIndex: response.correctIndex,
                correctOption: response.correctOption,
                canonicalDefinition: response.canonicalDefinition
            )
            var updated = state
            updated.recordOutcome(outcome)
            phase = .revealing(updated, outcome)
        } catch {
            phase = .failed(Self.describe(error))
        }
    }

    public func next() async {
        guard case .revealing(let state, _) = phase else { return }
        var updated = state
        updated.advance()
        if updated.currentQuestion == nil {
            phase = .completing(updated)
            await complete(state: updated)
        } else {
            questionShownAt = .now
            phase = .answering(updated)
        }
    }

    private func complete(state: LessonState) async {
        do {
            let summary = try await client.completeLesson(lessonId: state.lessonId)
            phase = .summary(summary)
            // T040 — persist the mode that was just played so next launch defaults to it.
            // Best-effort: a failed PATCH must not break the summary UI.
            Task.detached { [client, mode] in
                _ = try? await client.patchMePreferredMode(mode.rawValue)
            }
        } catch {
            phase = .failed(Self.describe(error))
        }
    }

    private static func describe(_ error: Error) -> String {
        if let backend = error as? BackendClientError {
            switch backend {
            case .invalidURL: return "Internal URL error"
            case .transport(let inner): return "Network error: \(inner.localizedDescription)"
            case .http(let status, _): return "Server returned HTTP \(status)"
            case .decoding: return "Could not read the server response"
            }
        }
        return error.localizedDescription
    }
}
