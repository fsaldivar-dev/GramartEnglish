import SwiftUI
import BackendClient

@MainActor
public final class OllamaStatusModel: ObservableObject {
    @Published public private(set) var available: Bool = true
    private let client: BackendClient
    private var task: Task<Void, Never>?

    public init(client: BackendClient) {
        self.client = client
    }

    public func startPolling(every seconds: TimeInterval = 10) {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.probe()
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }

    public func stopPolling() {
        task?.cancel()
        task = nil
    }

    private func probe() async {
        do {
            let health = try await client.health()
            available = health.ollamaAvailable
        } catch {
            available = false
        }
    }
}

struct OllamaStatusIndicator: View {
    @ObservedObject var model: OllamaStatusModel

    var body: some View {
        Group {
            if model.available {
                EmptyView()
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.slash")
                        .imageScale(.small)
                    Text("IA no disponible")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
                .accessibilityLabel("IA no disponible. El quiz sigue funcionando.")
            }
        }
    }
}
