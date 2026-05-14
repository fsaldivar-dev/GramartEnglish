import Foundation
import BackendClient

@MainActor
public final class WordExamplesViewModel: ObservableObject {

    public enum State: Equatable {
        case idle
        case loading
        case loaded(examples: [String], fallback: Bool)
        case failed(String)
    }

    @Published public private(set) var state: State = .idle
    private let client: BackendClient
    public let word: String
    public let level: String

    public init(client: BackendClient, word: String, level: String) {
        self.client = client
        self.word = word
        self.level = level
    }

    public func load() async {
        state = .loading
        do {
            let response = try await client.wordExamples(word: word, level: level)
            state = .loaded(examples: response.examples, fallback: response.fallback)
        } catch {
            state = .failed(describe(error))
        }
    }

    private func describe(_ error: Error) -> String {
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
