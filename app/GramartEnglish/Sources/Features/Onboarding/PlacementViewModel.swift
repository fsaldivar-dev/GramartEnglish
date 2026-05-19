import Foundation
import BackendClient

@MainActor
public final class PlacementViewModel: ObservableObject {

    public enum State: Equatable {
        case idle
        case loading
        case running(questions: [BackendClient.PlacementQuestion], currentIndex: Int, answers: [BackendClient.PlacementAnswer])
        case submitting
        case finished(BackendClient.PlacementResultResponse)
        case failed(String)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.submitting, .submitting): return true
            case let (.running(lq, li, la), .running(rq, ri, ra)): return lq == rq && li == ri && la == ra
            case let (.finished(l), .finished(r)): return l == r
            case let (.failed(l), .failed(r)): return l == r
            default: return false
            }
        }
    }

    @Published public private(set) var state: State = .idle
    private let client: BackendClient
    private var placementId: String = ""

    public init(client: BackendClient) {
        self.client = client
    }

    public func start() async {
        state = .loading
        do {
            let response = try await client.startPlacement(seed: nil)
            placementId = response.placementId
            state = .running(questions: response.questions, currentIndex: 0, answers: [])
        } catch {
            state = .failed(Self.describe(error))
        }
    }

    public func currentQuestion() -> BackendClient.PlacementQuestion? {
        guard case let .running(qs, idx, _) = state else { return nil }
        return idx < qs.count ? qs[idx] : nil
    }

    public func progress() -> (current: Int, total: Int)? {
        guard case let .running(qs, idx, _) = state else { return nil }
        return (idx + 1, qs.count)
    }

    public func answer(_ optionIndex: Int) async {
        guard case .running(let questions, let idx, var answers) = state, idx < questions.count else { return }
        // -1 means "I don't know"; record locally as a skip (no submission for that question).
        if optionIndex >= 0 {
            answers.append(.init(questionId: questions[idx].id, optionIndex: optionIndex))
        }
        let nextIdx = idx + 1
        if nextIdx < questions.count {
            state = .running(questions: questions, currentIndex: nextIdx, answers: answers)
        } else {
            await submit(answers: answers)
        }
    }

    private func submit(answers: [BackendClient.PlacementAnswer]) async {
        state = .submitting
        do {
            // Guard against an entirely-skipped placement; backend requires ≥1 answer.
            let safeAnswers = answers.isEmpty
                ? [BackendClient.PlacementAnswer(questionId: UUID().uuidString.lowercased(), optionIndex: 0)]
                : answers
            let result = try await client.submitPlacement(placementId: placementId, answers: safeAnswers)
            state = .finished(result)
        } catch {
            state = .failed(Self.describe(error))
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
