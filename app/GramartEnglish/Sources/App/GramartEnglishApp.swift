import SwiftUI
import AppKit
import BackendClient

@main
struct GramartEnglishApp: App {
    @NSApplicationDelegateAdaptor(GramartAppDelegate.self) private var appDelegate
    @StateObject private var bootstrap = AppBootstrap()

    var body: some Scene {
        WindowGroup("GramartEnglish") {
            RootFlowView()
                .environmentObject(bootstrap)
                .task { await bootstrap.start() }
                .frame(minWidth: 900, minHeight: 640)
        }
        .windowResizability(.contentSize)
    }
}

/// Forces proper app activation when the binary is launched without an
/// `.app` bundle (i.e. via `swift run` from Terminal). Without this, macOS
/// shows our window but keeps Terminal as the active app, so keystrokes go
/// nowhere useful and the user can't type into TextFields.
final class GramartAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            // First key-window pass: when the window opens it isn't always key
            // because the activation event arrives a tick later.
            for win in NSApp.windows where win.canBecomeKey {
                win.makeKeyAndOrderFront(nil)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for win in sender.windows where win.canBecomeKey {
                win.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

@MainActor
final class AppBootstrap: ObservableObject {
    enum State: Equatable {
        case launching
        case ready(BackendClient.HealthResponse)
        case failed(String)
    }

    @Published private(set) var state: State = .launching
    private let supervisor = BackendSupervisor()
    private var backendURL: URL?

    func start() async {
        FileLogger.shared.log("info", "app.launch.begin")

        // For Phase 2 the supervisor is wired but the backend binary is not yet
        // bundled into the .app. In development we expect a backend already
        // running locally (see GRAMART_BACKEND_URL); in production this branch
        // launches the embedded backend via BackendSupervisor.
        if let urlString = ProcessInfo.processInfo.environment["GRAMART_BACKEND_URL"],
           let url = URL(string: urlString) {
            self.backendURL = url
            await probeBackend(at: url)
        } else {
            state = .failed(
                "No embedded backend bundled yet. Set GRAMART_BACKEND_URL to a running backend for dev."
            )
            FileLogger.shared.log("warn", "app.launch.no_backend_url")
        }
    }

    func makeClient() -> BackendClient {
        let url = backendURL ?? URL(string: "http://127.0.0.1:0")!
        return BackendClient(baseURL: url)
    }

    private func probeBackend(at url: URL) async {
        let client = BackendClient(baseURL: url)
        do {
            let health = try await client.health()
            state = .ready(health)
            FileLogger.shared.log("info", "app.launch.ready", fields: [
                "version": health.version,
                "ollamaAvailable": String(health.ollamaAvailable),
            ])
        } catch {
            state = .failed("Backend health probe failed: \(error.localizedDescription)")
            FileLogger.shared.log("error", "app.launch.health_failed", fields: [
                "error": "\(error)",
            ])
        }
    }
}

struct LaunchingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Preparando todo…")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparando todo")
    }
}

struct ScaffoldFailedView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("No pude conectar con el servidor local")
                .font(.title2)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
        .padding()
    }
}
