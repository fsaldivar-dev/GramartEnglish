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

        // Two launch paths:
        //   1. Dev / CI: `GRAMART_BACKEND_URL` points at a backend you started
        //      separately (`pnpm dev` or `./scripts/dev.sh backend`).
        //   2. Production .app: the backend is bundled inside
        //      `Contents/Resources/backend/`. Spawn it via BackendSupervisor.
        if let urlString = ProcessInfo.processInfo.environment["GRAMART_BACKEND_URL"],
           let url = URL(string: urlString) {
            self.backendURL = url
            await probeBackend(at: url)
            return
        }

        await launchEmbeddedBackend()
    }

    private func launchEmbeddedBackend() async {
        FileLogger.shared.log("info", "app.launch.embedded.step1_resolve_bundle")
        guard let resourceDir = Bundle.main.resourceURL else {
            state = .failed("No Bundle.main.resourceURL — not running from an .app bundle")
            FileLogger.shared.log("error", "app.launch.embedded.no_resource_url")
            return
        }
        let backendDir = resourceDir.appendingPathComponent("backend", isDirectory: true)
        let nodeBinary = backendDir.appendingPathComponent("node")
        let scriptPath = backendDir.appendingPathComponent("bundle.mjs")

        FileLogger.shared.log("info", "app.launch.embedded.step2_check_binary", fields: [
            "nodePath": nodeBinary.path,
            "exists": String(FileManager.default.fileExists(atPath: nodeBinary.path)),
            "executable": String(FileManager.default.isExecutableFile(atPath: nodeBinary.path)),
        ])
        guard FileManager.default.isExecutableFile(atPath: nodeBinary.path) else {
            state = .failed(
                "Embedded backend missing at \(backendDir.path). Run scripts/package-backend.sh + scripts/build-app.sh to produce a runnable .app."
            )
            FileLogger.shared.log("error", "app.launch.no_embedded_backend", fields: ["path": backendDir.path])
            return
        }

        // Persistent DB lives in ~/.gramart-english/app.db so user data
        // survives app updates and lives outside the .app bundle (which is
        // read-only when installed in /Applications).
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let dbDir = support.appendingPathComponent("GramartEnglish", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbFile = dbDir.appendingPathComponent("app.db")

        let opts = BackendSupervisor.LaunchOptions(
            nodeBinary: nodeBinary,
            scriptPath: scriptPath,
            workingDirectory: backendDir,
            environment: [
                "NODE_ENV": "production",
                "GRAMART_DB": dbFile.path,
                "GRAMART_REPO_ROOT": backendDir.path,
            ],
            maxRelaunches: 2
        )

        FileLogger.shared.log("info", "app.launch.embedded.step3_spawning")
        do {
            let handshake = try await supervisor.start(opts)
            let url = URL(string: "http://127.0.0.1:\(handshake.port)")!
            self.backendURL = url
            FileLogger.shared.log("info", "app.launch.embedded_started", fields: [
                "port": String(handshake.port),
                "pid": String(handshake.pid),
                "version": handshake.version,
            ])
            await probeBackend(at: url)
        } catch {
            state = .failed("Failed to launch embedded backend: \(error)")
            FileLogger.shared.log("error", "app.launch.embedded_failed", fields: ["error": "\(error)"])
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
