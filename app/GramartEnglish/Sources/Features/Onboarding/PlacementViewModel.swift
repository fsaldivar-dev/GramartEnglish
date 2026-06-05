import Foundation
import BackendClient

@MainActor
public final class PlacementViewModel: ObservableObject {

    public enum State: Equatable {
        case selfReport
        case loading
        case question(current: Int, max: Int, q: BackendClient.PlacementQuestion)
        case submitting
        case finished(BackendClient.PlacementResultResponse)
        case failed(String)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.selfReport, .selfReport), (.loading, .loading), (.submitting, .submitting): return true
            case let (.question(lc, lm, lq), .question(rc, rm, rq)):
                return lc == rc && lm == rm && lq == rq
            case let (.finished(l), .finished(r)): return l == r
            case let (.failed(l), .failed(r)): return l == r
            default: return false
            }
        }
    }

    @Published public private(set) var state: State = .selfReport
    private let client: BackendClient
    private var placementId: String = ""

    public init(client: BackendClient) {
        self.client = client
    }

    /// Restart the test from the self-report screen.
    public func reset() {
        state = .selfReport
        placementId = ""
    }

    public func start(selfReport: BackendClient.PlacementSelfReport?) async {
        state = .loading
        do {
            let response = try await client.startAdaptivePlacement(seed: nil, selfReport: selfReport)
            placementId = response.placementId
            state = .question(
                current: response.progress.current,
                max: response.progress.max,
                q: response.question
            )
        } catch {
            state = .failed(Self.describe(error))
        }
    }

    public func currentQuestion() -> BackendClient.PlacementQuestion? {
        if case let .question(_, _, q) = state { return q }
        return nil
    }

    public func progress() -> (current: Int, total: Int)? {
        if case let .question(c, m, _) = state { return (c, m) }
        return nil
    }

    public func answer(_ optionIndex: Int) async {
        guard case let .question(_, _, q) = state else { return }
        do {
            let res = try await client.answerPlacement(
                placementId: placementId,
                questionId: q.id,
                optionIndex: optionIndex
            )
            switch res {
            case let .continue(question: nextQ, progress: p):
                state = .question(current: p.current, max: p.max, q: nextQ)
            case let .done(result: r):
                state = .finished(r)
            }
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
