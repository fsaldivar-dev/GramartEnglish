import Foundation

public enum BackendClientError: Error, Sendable {
    case invalidURL
    case transport(Error)
    case http(status: Int, body: String)
    case decoding(Error)
}

public struct BackendClient: Sendable {
    public static let apiVersionPath = "/v1"
    /// Sent on every request as `X-Client-Version`. The backend uses this to
    /// branch placement /start between the v1.3 (legacy 24-question) and the
    /// v1.4+ (adaptive single-question) shapes.
    public static let clientVersion = "1.8.0"

    public let baseURL: URL
    public let session: URLSession
    public let correlationIdProvider: @Sendable () -> String

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        correlationIdProvider: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.correlationIdProvider = correlationIdProvider
    }

    // MARK: - Generic request

    public func get<Response: Decodable>(_ path: String, as: Response.Type) async throws -> Response {
        try await request(method: "GET", path: path, body: Empty?.none, as: Response.self)
    }

    public func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        as: Response.Type
    ) async throws -> Response {
        try await request(method: "POST", path: path, body: body, as: Response.self)
    }

    private struct Empty: Codable {}

    private func request<Body: Encodable, Response: Decodable>(
        method: String,
        path: String,
        body: Body?,
        as: Response.Type
    ) async throws -> Response {
        guard let url = URL(string: Self.apiVersionPath + path, relativeTo: baseURL) else {
            throw BackendClientError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(correlationIdProvider(), forHTTPHeaderField: "x-correlation-id")
        req.setValue(Self.clientVersion, forHTTPHeaderField: "x-client-version")
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw BackendClientError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.http(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BackendClientError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw BackendClientError.decoding(error)
        }
    }

    // MARK: - Typed endpoints

    public struct HealthResponse: Codable, Sendable, Equatable {
        public let status: String
        public let version: String
        public let schemaVersion: Int
        public let ollamaAvailable: Bool
    }

    public func health() async throws -> HealthResponse {
        try await get("/health", as: HealthResponse.self)
    }

    public struct LevelInfo: Codable, Sendable, Equatable, Identifiable {
        public let code: String
        public let label: String
        public var id: String { code }
    }

    public func levels() async throws -> [LevelInfo] {
        try await get("/levels", as: [LevelInfo].self)
    }

    // MARK: - Placement

    public struct PlacementQuestion: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let word: String
        public let sentence: String?
        public let options: [String]
        public let level: String
    }

    /// Legacy v1.3 shape — 24 questions upfront. Returned when the backend
    /// doesn't see `x-client-version: 1.4+`. The v1.4 client never sees this
    /// shape because we always send the header.
    public struct PlacementStartResponse: Codable, Sendable, Equatable {
        public let placementId: String
        public let questions: [PlacementQuestion]
    }

    /// v1.4 adaptive shape — single question + progress hint.
    public struct PlacementStartAdaptiveResponse: Codable, Sendable, Equatable {
        public let placementId: String
        public let question: PlacementQuestion
        public let progress: PlacementProgress
        public let algorithmVersion: String
    }

    public struct PlacementProgress: Codable, Sendable, Equatable {
        public let current: Int
        public let max: Int
    }

    public enum PlacementSelfReport: String, Codable, Sendable, CaseIterable {
        case never, some, lots
    }

    public struct PlacementStartRequest: Codable, Sendable {
        public let seed: Int?
        public let selfReport: String?  // PlacementSelfReport.rawValue, kept as String for back-compat
        public init(seed: Int? = nil, selfReport: PlacementSelfReport? = nil) {
            self.seed = seed
            self.selfReport = selfReport?.rawValue
        }
    }

    /// Legacy v1.3-style start. Kept for backwards compatibility with code
    /// that might still call it; new code uses `startAdaptivePlacement`.
    public func startPlacement(seed: Int? = nil) async throws -> PlacementStartResponse {
        try await post("/placement/start", body: PlacementStartRequest(seed: seed), as: PlacementStartResponse.self)
    }

    /// v1.4 adaptive start — backend honors `x-client-version` and returns the
    /// adaptive shape automatically.
    public func startAdaptivePlacement(
        seed: Int? = nil,
        selfReport: PlacementSelfReport? = nil
    ) async throws -> PlacementStartAdaptiveResponse {
        try await post(
            "/placement/start",
            body: PlacementStartRequest(seed: seed, selfReport: selfReport),
            as: PlacementStartAdaptiveResponse.self
        )
    }

    public struct PlacementAnswerRequest: Codable, Sendable {
        public let placementId: String
        public let questionId: String
        public let optionIndex: Int  // -1 means "no lo sé"
        public init(placementId: String, questionId: String, optionIndex: Int) {
            self.placementId = placementId
            self.questionId = questionId
            self.optionIndex = optionIndex
        }
    }

    /// v1.4 — server-streamed discriminated union: either a continuation or a
    /// terminal result. Decoded via `kind` discriminator.
    public enum PlacementAnswerResponse: Sendable, Equatable {
        case `continue`(question: PlacementQuestion, progress: PlacementProgress)
        case done(result: PlacementResultResponse)
    }

    public func answerPlacement(
        placementId: String,
        questionId: String,
        optionIndex: Int
    ) async throws -> PlacementAnswerResponse {
        let raw = try await post(
            "/placement/answer",
            body: PlacementAnswerRequest(placementId: placementId, questionId: questionId, optionIndex: optionIndex),
            as: PlacementAnswerRaw.self
        )
        switch raw.kind {
        case "continue":
            guard let q = raw.question, let p = raw.progress else {
                throw BackendClientError.decoding(NSError(domain: "PlacementAnswer", code: 1))
            }
            return .continue(question: q, progress: p)
        case "done":
            guard let r = raw.result else {
                throw BackendClientError.decoding(NSError(domain: "PlacementAnswer", code: 2))
            }
            return .done(result: r)
        default:
            throw BackendClientError.decoding(NSError(domain: "PlacementAnswer", code: 3))
        }
    }

    private struct PlacementAnswerRaw: Codable {
        let kind: String
        let question: PlacementQuestion?
        let progress: PlacementProgress?
        let result: PlacementResultResponse?
    }

    public struct PlacementAnswer: Codable, Sendable, Equatable {
        public let questionId: String
        public let optionIndex: Int
        public init(questionId: String, optionIndex: Int) {
            self.questionId = questionId
            self.optionIndex = optionIndex
        }
    }

    public struct PlacementSubmitRequest: Codable, Sendable {
        public let placementId: String
        public let answers: [PlacementAnswer]
        public init(placementId: String, answers: [PlacementAnswer]) {
            self.placementId = placementId
            self.answers = answers
        }
    }

    public struct PerLevelScore: Codable, Sendable, Equatable {
        public let attempted: Int
        public let correct: Int
    }

    public struct PlacementResultResponse: Codable, Sendable, Equatable {
        public let estimatedLevel: String
        public let perLevelScores: [String: PerLevelScore]
        /// v1.4+. Optional — "v1" for legacy batch, "v2" for adaptive.
        public let algorithmVersion: String?
        /// v1.4+. Number of items the adaptive test administered.
        public let itemsAdministered: Int?

        public init(
            estimatedLevel: String,
            perLevelScores: [String: PerLevelScore],
            algorithmVersion: String? = nil,
            itemsAdministered: Int? = nil
        ) {
            self.estimatedLevel = estimatedLevel
            self.perLevelScores = perLevelScores
            self.algorithmVersion = algorithmVersion
            self.itemsAdministered = itemsAdministered
        }
    }

    public func submitPlacement(placementId: String, answers: [PlacementAnswer]) async throws -> PlacementResultResponse {
        try await post(
            "/placement/submit",
            body: PlacementSubmitRequest(placementId: placementId, answers: answers),
            as: PlacementResultResponse.self
        )
    }

    // MARK: - Lessons

    public struct LessonQuestionDTO: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let word: String
        public let options: [String]
        public let position: Int
        /// v1.3+. Spanish meaning when the server picks a write mode. Clients
        /// MUST render this in place of `word` when present.
        public let prompt: String?
        /// v1.5+. Scaffolded English word with underscores for `write_fill_gaps`.
        /// Omitted by the server when the word was short enough to auto-promote
        /// to plain typed input — clients then render exactly like `write_type_word`.
        public let maskedWord: String?
        /// v1.6+. For `conjugate_pick_form`: English base form of the verb
        /// (e.g. "go" when the answer is "went"). Omitted for other modes.
        public let verbBase: String?
        /// v1.6+. For `conjugate_pick_form`: target tense. v1.6.0 ships only
        /// `"simple_past"`. Omitted for other modes.
        public let targetTense: String?
        /// v1.6.0 patch (Blocker 2). For `conjugate_pick_form` only — Spanish
        /// example with `___` slot, disambiguates tense for the learner.
        public let exampleEs: String?
        /// v1.6.0 patch (Blocker 2). For `conjugate_pick_form` only — English
        /// example with the verb conjugated. Revealed post-answer.
        public let exampleEn: String?
    }

    public struct StartLessonRequest: Codable, Sendable {
        public let level: String
        public let mode: String?
        public init(level: String, mode: String? = nil) {
            self.level = level
            self.mode = mode
        }
    }

    public struct StartLessonResponse: Codable, Sendable, Equatable {
        public let lessonId: String
        public let mode: String?
        public let questions: [LessonQuestionDTO]
    }

    /// Start a lesson. `mode` defaults to `read_pick_meaning` server-side when omitted.
    public func startLesson(level: String, mode: String? = nil) async throws -> StartLessonResponse {
        try await post(
            "/lessons",
            body: StartLessonRequest(level: level, mode: mode),
            as: StartLessonResponse.self
        )
    }

    /// F007 patch (v1.8.0). Resume an in-flight lesson by id. The backend
    /// returns the remaining (unanswered) questions plus the persisted mode
    /// in the same shape as `startLesson`, so the caller can drop the result
    /// into the existing answering flow without branching.
    ///
    /// Throws `.http(404)` if the lesson is unknown or already completed —
    /// callers should clear the local snapshot in that case and fall back
    /// to a fresh `startLesson`.
    public struct ResumeLessonResponse: Codable, Sendable, Equatable {
        public let lessonId: String
        public let mode: String?
        public let level: String?
        public let questions: [LessonQuestionDTO]
        /// Number of questions already answered server-side. The client uses
        /// this to keep the progress strip in sync on resume.
        public let answeredCount: Int?
        public let totalCount: Int?
    }

    public func resumeLesson(lessonId: String) async throws -> ResumeLessonResponse {
        try await get("/lessons/\(lessonId)", as: ResumeLessonResponse.self)
    }

    public struct AnswerLessonRequest: Codable, Sendable {
        public let questionId: String
        public let optionIndex: Int?
        public let typedAnswer: String?
        /// v1.3+. Set true when the user revealed letters via the hint button
        /// (write_type_word, write_fill_gaps). Backend zeroes the
        /// consecutiveCorrect streak even on a correct answer (FR-009).
        public let hintUsed: Bool?
        public let answerMs: Int
        public init(
            questionId: String,
            optionIndex: Int? = nil,
            typedAnswer: String? = nil,
            hintUsed: Bool? = nil,
            answerMs: Int
        ) {
            self.questionId = questionId
            self.optionIndex = optionIndex
            self.typedAnswer = typedAnswer
            self.hintUsed = hintUsed
            self.answerMs = answerMs
        }
    }

    public enum Outcome: String, Codable, Sendable, Equatable {
        case correct, incorrect, skipped
    }

    public struct AnswerLessonResponse: Codable, Sendable, Equatable {
        public let outcome: Outcome
        public let correctIndex: Int
        public let correctOption: String
        public let canonicalDefinition: String
        public let typedAnswerEcho: String?
        /// F007 (v1.8.0). Server-supplied teaching line shown post-answer.
        /// Populated when the learner committed to an over-regularized form
        /// of an irregular verb (e.g. typed `goed`). Absent otherwise.
        public let feedbackHint: String?

        public init(
            outcome: Outcome,
            correctIndex: Int,
            correctOption: String,
            canonicalDefinition: String,
            typedAnswerEcho: String? = nil,
            feedbackHint: String? = nil
        ) {
            self.outcome = outcome
            self.correctIndex = correctIndex
            self.correctOption = correctOption
            self.canonicalDefinition = canonicalDefinition
            self.typedAnswerEcho = typedAnswerEcho
            self.feedbackHint = feedbackHint
        }
    }

    /// Option-picking modes (read_pick_meaning, listen_pick_word, listen_pick_meaning).
    public func answerLesson(
        lessonId: String,
        questionId: String,
        optionIndex: Int,
        answerMs: Int
    ) async throws -> AnswerLessonResponse {
        try await post(
            "/lessons/\(lessonId)/answers",
            body: AnswerLessonRequest(questionId: questionId, optionIndex: optionIndex, answerMs: answerMs),
            as: AnswerLessonResponse.self
        )
    }

    /// Typed-input modes (listen_type, write_type_word, write_fill_gaps).
    /// `hintUsed: true` resets the mastery streak per FR-009.
    public func answerLesson(
        lessonId: String,
        questionId: String,
        typedAnswer: String,
        hintUsed: Bool = false,
        answerMs: Int
    ) async throws -> AnswerLessonResponse {
        try await post(
            "/lessons/\(lessonId)/answers",
            body: AnswerLessonRequest(
                questionId: questionId,
                typedAnswer: typedAnswer,
                hintUsed: hintUsed ? true : nil,
                answerMs: answerMs
            ),
            as: AnswerLessonResponse.self
        )
    }

    public struct SkipLessonRequest: Codable, Sendable {
        public let questionId: String
        public let answerMs: Int
        public init(questionId: String, answerMs: Int) {
            self.questionId = questionId
            self.answerMs = answerMs
        }
    }

    public func skipLesson(
        lessonId: String,
        questionId: String,
        answerMs: Int
    ) async throws -> AnswerLessonResponse {
        try await post(
            "/lessons/\(lessonId)/skip",
            body: SkipLessonRequest(questionId: questionId, answerMs: answerMs),
            as: AnswerLessonResponse.self
        )
    }

    public struct LessonSummaryResponse: Codable, Sendable, Equatable {
        public let lessonId: String
        public let score: Int
        public let skipped: Int
        public let wrong: Int
        public let total: Int
        public let missedWords: [MissedWord]

        public struct MissedWord: Codable, Sendable, Equatable, Identifiable {
            public let word: String
            public let canonicalDefinition: String
            public let outcome: Outcome
            public var id: String { word }
        }
    }

    private struct Empty2: Codable {}

    public func completeLesson(lessonId: String) async throws -> LessonSummaryResponse {
        try await post("/lessons/\(lessonId)/complete", body: Empty2(), as: LessonSummaryResponse.self)
    }

    // MARK: - Verb intro (F006, v1.7.0)

    /// Pre-conjugation micro-card payload. Returned by
    /// `GET /v1/verbs/{base}/intro`.
    ///
    /// `exampleEs` keeps its `___` slot — the conjugation drill uses it as
    /// the question. `exampleEsFilled` (v1.7.0 patch) is the same sentence
    /// with the Spanish past form substituted; the intro card renders that
    /// so the teaching surface never shows a literal blank.
    public struct VerbIntro: Codable, Sendable, Equatable {
        public let base: String
        public let es: String
        public let exampleEs: String
        public let exampleEsFilled: String
        public let exampleEn: String
        public let audioBase: String

        public init(base: String, es: String, exampleEs: String, exampleEsFilled: String, exampleEn: String, audioBase: String) {
            self.base = base
            self.es = es
            self.exampleEs = exampleEs
            self.exampleEsFilled = exampleEsFilled
            self.exampleEn = exampleEn
            self.audioBase = audioBase
        }
    }

    /// Fetches the verb intro payload. Returns `nil` on 404 (unknown verb);
    /// throws on transport / non-404 HTTP / decode failures.
    public func fetchVerbIntro(base: String) async throws -> VerbIntro? {
        guard let url = URL(string: Self.apiVersionPath + "/verbs/\(base)/intro", relativeTo: baseURL) else {
            throw BackendClientError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(correlationIdProvider(), forHTTPHeaderField: "x-correlation-id")
        req.setValue(Self.clientVersion, forHTTPHeaderField: "x-client-version")
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: req) } catch { throw BackendClientError.transport(error) }
        guard let http = response as? HTTPURLResponse else { throw BackendClientError.http(status: -1, body: "") }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else {
            throw BackendClientError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        do { return try JSONDecoder().decode(VerbIntro.self, from: data) }
        catch { throw BackendClientError.decoding(error) }
    }

    // MARK: - AI examples / definition

    public struct ExamplesResponse: Codable, Sendable, Equatable {
        public let examples: [String]
        public let sourceIds: [Int]?
        public let generatedBy: String
        public let fallback: Bool
    }

    public struct DefinitionResponse: Codable, Sendable, Equatable {
        public let definition: String
        public let sourceIds: [Int]?
        public let generatedBy: String
        public let fallback: Bool
    }

    /// Calls `/v1/words/{word}/examples`. Treats both 200 and 503 as success when
    /// the body contains a usable result; only network/decoding errors throw.
    public func wordExamples(word: String, level: String) async throws -> ExamplesResponse {
        try await getOrFallback("/words/\(word)/examples?level=\(level)", as: ExamplesResponse.self)
    }

    public func wordDefinition(word: String, level: String) async throws -> DefinitionResponse {
        try await getOrFallback("/words/\(word)/definition?level=\(level)", as: DefinitionResponse.self)
    }

    private func getOrFallback<Response: Decodable>(_ path: String, as: Response.Type) async throws -> Response {
        guard let url = URL(string: Self.apiVersionPath + path, relativeTo: baseURL) else {
            throw BackendClientError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(correlationIdProvider(), forHTTPHeaderField: "x-correlation-id")
        req.setValue(Self.clientVersion, forHTTPHeaderField: "x-client-version")
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: req) } catch { throw BackendClientError.transport(error) }
        guard let http = response as? HTTPURLResponse else { throw BackendClientError.http(status: -1, body: "") }
        if (200..<300).contains(http.statusCode) || http.statusCode == 503 {
            do { return try JSONDecoder().decode(Response.self, from: data) }
            catch { throw BackendClientError.decoding(error) }
        }
        throw BackendClientError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
    }

    // MARK: - Progress + Me

    public struct ProgressResponse: Codable, Sendable, Equatable {
        public let currentLevel: String
        public let lessonsCompleted: Int
        public let masteredCount: Int
        public let toReviewCount: Int
        public let lastLesson: LastLesson?
        public let resumable: ResumableLesson?
        /// Per-mode mastered counts. Keys are LessonMode raw values
        /// (`read_pick_meaning`, `listen_pick_word`, `listen_pick_meaning`, `listen_type`).
        public let perModeMastered: [String: Int]?
        /// The mode argmax(pendingWords) + LRU tiebreaker. Drives the
        /// "Recomendado para ti" badge on Home.
        public let recommendedMode: String?

        public struct LastLesson: Codable, Sendable, Equatable {
            public let lessonId: String
            public let score: Int
            public let total: Int
            public let level: String
            public let completedAt: String
        }
        public struct ResumableLesson: Codable, Sendable, Equatable {
            public let lessonId: String
            public let level: String
            public let answeredCount: Int
            public let totalCount: Int
        }
    }

    public func progress() async throws -> ProgressResponse {
        try await get("/progress", as: ProgressResponse.self)
    }

    public struct User: Codable, Sendable, Equatable {
        public let id: String
        public let currentLevel: String
        public let createdAt: String
        public let preferredMode: String?
    }

    public struct MePatchRequest: Codable, Sendable {
        public let currentLevel: String?
        public let preferredMode: String?
        public init(currentLevel: String? = nil, preferredMode: String? = nil) {
            self.currentLevel = currentLevel
            self.preferredMode = preferredMode
        }
    }

    public func me() async throws -> User {
        try await get("/me", as: User.self)
    }

    public func patchMeLevel(_ level: String) async throws -> User {
        try await request(method: "PATCH", path: "/me", body: MePatchRequest(currentLevel: level), as: User.self)
    }

    public func patchMePreferredMode(_ mode: String) async throws -> User {
        try await request(method: "PATCH", path: "/me", body: MePatchRequest(preferredMode: mode), as: User.self)
    }

    public struct ResetResponse: Codable, Sendable {
        public let ok: Bool
        public let user: User
    }

    private struct Empty3: Codable {}

    public func resetMe() async throws -> ResetResponse {
        try await post("/me/reset", body: Empty3(), as: ResetResponse.self)
    }
}
