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
    /// F006 (v1.7.0). When non-nil, the view dispatches `VerbIntroCard`
    /// instead of the question view for the current `.answering` state.
    /// Set by `presentIntroIfNeeded` before the first question that targets a
    /// previously-unseen verb; cleared by `dismissVerbIntro`.
    @Published public private(set) var pendingIntro: BackendClient.VerbIntro?
    /// F007 patch (v1.8.0). When the lesson was entered via a resume path
    /// (not a fresh start), this carries the snapshot metadata so the view
    /// can render the "Continuando…" banner with accurate Q{n}/{total}.
    /// Cleared after the first user gesture so the banner only shows once.
    @Published public var resumeBanner: ResumeBanner?
    public struct ResumeBanner: Equatable, Sendable {
        public let currentQuestionIndex: Int
        public let totalCount: Int
    }
    public let mode: LessonMode
    private let client: BackendClient
    private let level: String
    private var questionShownAt: Date = .now
    private var lastTypedEcho: String?
    private let verbIntroSeen: VerbIntroSeenStore
    /// F007 (v1.8.0). Persists an in-flight snapshot so Cmd+Q mid-lesson
    /// doesn't destroy progress. The VM does not read this store — the
    /// startup path in RootView does. The VM is the producer.
    private let stateStore: LessonStateStore

    public init(
        client: BackendClient,
        level: String,
        mode: LessonMode = .readPickMeaning,
        verbIntroSeen: VerbIntroSeenStore = .shared,
        stateStore: LessonStateStore = .shared
    ) {
        self.client = client
        self.level = level
        self.mode = mode
        self.verbIntroSeen = verbIntroSeen
        self.stateStore = stateStore
    }

    /// F007 (v1.8.0). Builds the disk snapshot for the current phase. Returns
    /// nil for phases where there is nothing meaningful to resume (idle,
    /// loading, summary, failed) — the caller (`persistSnapshot`) translates
    /// nil into a `clear()` of the store.
    private func snapshot(for phase: Phase) -> LessonStateSnapshot? {
        switch phase {
        case .answering(let state):
            return LessonStateSnapshot(
                lessonId: state.lessonId,
                mode: mode.rawValue,
                level: level,
                phase: .answering,
                currentQuestionIndex: state.currentIndex,
                answeredCount: state.outcomes.count
            )
        case .revealing(let state, _):
            return LessonStateSnapshot(
                lessonId: state.lessonId,
                mode: mode.rawValue,
                level: level,
                phase: .revealing,
                currentQuestionIndex: state.currentIndex,
                answeredCount: state.outcomes.count
            )
        case .idle, .loading, .completing, .summary, .failed:
            return nil
        }
    }

    /// F007 (v1.8.0). Called on every phase transition. If the phase
    /// represents an in-flight lesson the snapshot is saved (debounced);
    /// otherwise the store is cleared. Idempotent.
    private func persistSnapshot() {
        if let snap = snapshot(for: phase) {
            stateStore.save(snap)
        } else {
            stateStore.clear()
        }
    }

    public func start(resumeId: String? = nil) async {
        phase = .loading
        do {
            let lessonId: String
            let dtoQuestions: [BackendClient.LessonQuestionDTO]
            if let resumeId {
                // F007 patch (v1.8.0). Critical: take the GET path. POSTing
                // /lessons here would create a new lesson row and silently
                // discard ~15min of learner progress — the exact bug Marisol
                // and Priya independently flagged in QA.
                let resumed = try await client.resumeLesson(lessonId: resumeId)
                lessonId = resumed.lessonId
                dtoQuestions = resumed.questions
                if let answered = resumed.answeredCount, let total = resumed.totalCount {
                    resumeBanner = ResumeBanner(currentQuestionIndex: answered, totalCount: total)
                }
            } else {
                let response = try await client.startLesson(level: level, mode: mode.rawValue)
                lessonId = response.lessonId
                dtoQuestions = response.questions
            }
            let questions = dtoQuestions.map { q in
                LessonQuestion(
                    id: q.id,
                    word: q.word,
                    options: q.options,
                    position: q.position,
                    prompt: q.prompt,
                    maskedWord: q.maskedWord,
                    verbBase: q.verbBase,
                    targetTense: q.targetTense,
                    exampleEs: q.exampleEs,
                    exampleEn: q.exampleEn
                )
            }
            let state = LessonState(lessonId: lessonId, questions: questions)
            questionShownAt = .now
            phase = .answering(state)
            persistSnapshot()
            await presentIntroIfNeeded(for: state.currentQuestion)
        } catch {
            phase = .failed(Self.describe(error))
        }
    }

    /// F006 gating. If the mode is `conjugate_pick_form` and the question's
    /// verb base has not been dismissed before on this Mac, fetch the intro
    /// payload and stash it in `pendingIntro`. Any failure path
    /// (non-conjugate mode, no verbBase, already seen, 404, network error)
    /// degrades to "no intro" — the question view renders normally.
    func presentIntroIfNeeded(for question: LessonQuestion?) async {
        guard mode == .conjugatePickForm,
              let question,
              let base = question.verbBase, !base.isEmpty,
              !verbIntroSeen.hasSeen(base) else {
            return
        }
        do {
            if let intro = try await client.fetchVerbIntro(base: base) {
                pendingIntro = intro
            }
        } catch {
            // Degrade silently — the question view still works.
        }
    }

    /// Called by `VerbIntroCard.onDismiss`. Marks the verb seen and clears
    /// pendingIntro so the view falls through to the question. The order
    /// matters: markSeen first (so a fast re-render can't re-show the card).
    public func dismissVerbIntro() {
        if let base = pendingIntro?.base {
            verbIntroSeen.markSeen(base)
        }
        pendingIntro = nil
        questionShownAt = .now
        // F007 Polish A (v1.8.0). Persist on dismiss so a Cmd+Q in the
        // window between intro-dismissed and first-answer doesn't re-show
        // the intro card on relaunch — Priya's report.
        persistSnapshot()
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
                canonicalDefinition: response.canonicalDefinition,
                feedbackHint: response.feedbackHint
            )
            var updated = state
            updated.recordOutcome(outcome)
            lastTypedEcho = nil
            phase = .revealing(updated, outcome)
            persistSnapshot()
        } catch {
            phase = .failed(Self.describe(error))
            persistSnapshot()
        }
    }

    /// Submit a typed answer (listen_type, write_type_word, write_fill_gaps).
    /// Empty input is treated as skip. `hintUsed` flips the FR-009 streak reset
    /// on the backend (no mastery credit even on a correct typed answer).
    public func answerTyped(_ text: String, hintUsed: Bool = false) async {
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
                hintUsed: hintUsed,
                answerMs: elapsedMs
            )
            let outcome = AnswerOutcome(
                questionId: question.id,
                chosenIndex: nil,
                kind: AnswerKind(rawValue: response.outcome.rawValue) ?? .incorrect,
                correctIndex: response.correctIndex,
                correctOption: response.correctOption,
                canonicalDefinition: response.canonicalDefinition,
                feedbackHint: response.feedbackHint
            )
            var updated = state
            updated.recordOutcome(outcome)
            lastTypedEcho = response.typedAnswerEcho
            phase = .revealing(updated, outcome)
            persistSnapshot()
        } catch {
            phase = .failed(Self.describe(error))
            persistSnapshot()
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
                canonicalDefinition: response.canonicalDefinition,
                feedbackHint: response.feedbackHint
            )
            var updated = state
            updated.recordOutcome(outcome)
            phase = .revealing(updated, outcome)
            persistSnapshot()
        } catch {
            phase = .failed(Self.describe(error))
            persistSnapshot()
        }
    }

    public func next() async {
        guard case .revealing(let state, _) = phase else { return }
        var updated = state
        updated.advance()
        if updated.currentQuestion == nil {
            phase = .completing(updated)
            persistSnapshot()
            await complete(state: updated)
        } else {
            questionShownAt = .now
            phase = .answering(updated)
            persistSnapshot()
            await presentIntroIfNeeded(for: updated.currentQuestion)
        }
    }

    private func complete(state: LessonState) async {
        do {
            let summary = try await client.completeLesson(lessonId: state.lessonId)
            phase = .summary(summary)
            // F007: lesson is done — drop the snapshot eagerly. The
            // debounce-flush would happen on the next user gesture, but
            // tearing down the lesson chrome shouldn't race with persistence
            // for state nobody can resume into.
            stateStore.clear()
        } catch {
            phase = .failed(Self.describe(error))
            persistSnapshot()
        }
    }

    /// Best-effort persist the played mode so next launch defaults to it (T040).
    /// Caller decides when/whether to invoke; the view model never spawns
    /// a detached side-effect task (that pattern leaked across tests via a
    /// shared `URLProtocol.handler` static var on the test side).
    public func persistPreferredMode() async {
        _ = try? await client.patchMePreferredMode(mode.rawValue)
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
