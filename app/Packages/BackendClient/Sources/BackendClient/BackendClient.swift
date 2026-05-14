import Foundation

public enum BackendClientError: Error, Sendable {
    case invalidURL
    case transport(Error)
    case http(status: Int, body: String)
    case decoding(Error)
}

public struct BackendClient: Sendable {
    public static let apiVersionPath = "/v1"

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

    public struct PlacementStartResponse: Codable, Sendable, Equatable {
        public let placementId: String
        public let questions: [PlacementQuestion]
    }

    public struct PlacementStartRequest: Codable, Sendable {
        public let seed: Int?
        public init(seed: Int? = nil) { self.seed = seed }
    }

    public func startPlacement(seed: Int? = nil) async throws -> PlacementStartResponse {
        try await post("/placement/start", body: PlacementStartRequest(seed: seed), as: PlacementStartResponse.self)
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
    }

    public func submitPlacement(placementId: String, answers: [PlacementAnswer]) async throws -> PlacementResultResponse {
        try await post(
            "/placement/submit",
            body: PlacementSubmitRequest(placementId: placementId, answers: answers),
            as: PlacementResultResponse.self,
        )
    }

    // MARK: - Lessons

    public struct LessonQuestionDTO: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let word: String
        public let options: [String]
        public let position: Int
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
            as: StartLessonResponse.self,
        )
    }

    public struct AnswerLessonRequest: Codable, Sendable {
        public let questionId: String
        public let optionIndex: Int?
        public let typedAnswer: String?
        public let answerMs: Int
        public init(questionId: String, optionIndex: Int? = nil, typedAnswer: String? = nil, answerMs: Int) {
            self.questionId = questionId
            self.optionIndex = optionIndex
            self.typedAnswer = typedAnswer
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
            as: AnswerLessonResponse.self,
        )
    }

    /// Typed-input mode (listen_type). Mutually exclusive with `optionIndex` on the wire.
    public func answerLesson(
        lessonId: String,
        questionId: String,
        typedAnswer: String,
        answerMs: Int
    ) async throws -> AnswerLessonResponse {
        try await post(
            "/lessons/\(lessonId)/answers",
            body: AnswerLessonRequest(questionId: questionId, typedAnswer: typedAnswer, answerMs: answerMs),
            as: AnswerLessonResponse.self,
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
            as: AnswerLessonResponse.self,
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
