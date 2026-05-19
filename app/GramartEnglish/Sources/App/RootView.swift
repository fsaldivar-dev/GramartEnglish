import SwiftUI
import BackendClient
import LessonKit

/// The top-level navigation flow for the app.
struct RootFlowView: View {
    @EnvironmentObject private var bootstrap: AppBootstrap

    var body: some View {
        switch bootstrap.state {
        case .launching: LaunchingView()
        case .failed(let message): ScaffoldFailedView(message: message)
        case .ready(let health):
            ReadyFlowView(client: bootstrap.makeClient(), appVersion: health.version)
                .environmentObject(bootstrap)
                .accessibilityLabel("Backend version \(health.version)")
        }
    }
}

@MainActor
final class HomeProgressViewModel: ObservableObject {
    @Published var progress: BackendClient.ProgressResponse?
    private let client: BackendClient
    init(client: BackendClient) { self.client = client }
    func refresh() async {
        progress = try? await client.progress()
    }
}

struct ReadyFlowView: View {
    @StateObject private var placement: PlacementViewModel
    @StateObject private var statusModel: OllamaStatusModel
    @StateObject private var home: HomeProgressViewModel
    @State private var phase: Phase = .launching
    @State private var showSettings: Bool = false
    @State private var settingsPresentationId: Int = 0
    @State private var showMyWords: Bool = false
    private let client: BackendClient
    private let appVersion: String

    enum Phase: Equatable {
        case launching
        case welcome
        case placement
        case result(BackendClient.PlacementResultResponse)
        case home(level: String)
        case lesson(level: String, mode: LessonMode, resumeId: String?)
    }

    init(client: BackendClient, appVersion: String) {
        self.client = client
        self.appVersion = appVersion
        _placement = StateObject(wrappedValue: PlacementViewModel(client: client))
        _statusModel = StateObject(wrappedValue: OllamaStatusModel(client: client))
        _home = StateObject(wrappedValue: HomeProgressViewModel(client: client))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            switch phase {
            case .launching:
                ProgressView()
            case .welcome:
                WelcomeView(
                    onStart: { Task { phase = .placement; await placement.start() } },
                    onSkip: { Task { await goHome(level: "A2") } }
                )
            case .placement:
                placementBody
            case .result(let result):
                PlacementResultView(
                    result: result,
                    onAccept: { Task { await goHome(level: result.estimatedLevel) } },
                    onPickAnother: { phase = .welcome }
                )
            case .home(let level):
                HomeView(
                    level: level,
                    progress: home.progress,
                    onStartLessonInMode: { mode in phase = .lesson(level: level, mode: mode, resumeId: nil) },
                    onResume: { id in
                        // Resumed lessons replay in the mode they were started in;
                        // the backend tracks the mode on the lesson row. For now we
                        // pass `readPickMeaning` since the resume path goes through
                        // its own endpoint that doesn't need the mode echoed here.
                        phase = .lesson(level: level, mode: .readPickMeaning, resumeId: id)
                    },
                    onOpenSettings: { settingsPresentationId += 1; showSettings = true },
                    onOpenMyWords: { showMyWords = true }
                )
            case .lesson(let level, let mode, _):
                LessonFlowView(
                    client: client,
                    level: level,
                    mode: mode,
                    onExit: { Task { await goHome(level: level) } }
                )
            }

            OllamaStatusIndicator(model: statusModel)
                .padding(.top, 12)
                .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { statusModel.startPolling(); await initialPhase() }
        .onChange(of: placement.state) { _, newState in
            if case .finished(let result) = newState {
                phase = .result(result)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                viewModel: SettingsViewModel(
                    client: client,
                    initialLevel: currentLevel,
                    onLevelChanged: { newLevel in
                        Task {
                            await home.refresh()
                            if case .home = phase { phase = .home(level: newLevel) }
                            showSettings = false
                        }
                    },
                    onReset: {
                        Task {
                            showSettings = false
                            await home.refresh()
                            phase = .welcome
                        }
                    }
                ),
                appVersion: appVersion,
                onClose: { showSettings = false }
            )
            .id(settingsPresentationId)
        }
        .sheet(isPresented: $showMyWords) {
            MyWordsView(progress: home.progress, onClose: { showMyWords = false })
                .task { await home.refresh() }
        }
    }

    private var currentLevel: String {
        if case let .home(level) = phase { return level }
        if case let .lesson(level, _, _) = phase { return level }
        return home.progress?.currentLevel ?? "A2"
    }

    private func initialPhase() async {
        await home.refresh()
        if let p = home.progress, p.lessonsCompleted > 0 || p.resumable != nil {
            phase = .home(level: p.currentLevel)
        } else {
            phase = .welcome
        }
    }

    private func goHome(level: String) async {
        await home.refresh()
        phase = .home(level: home.progress?.currentLevel ?? level)
    }

    @ViewBuilder
    private var placementBody: some View {
        switch placement.state {
        case .idle, .loading, .submitting:
            VStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text(placement.state == .submitting ? "Scoring…" : "Loading questions…")
                    .foregroundStyle(.secondary)
            }
        case .running:
            if let q = placement.currentQuestion(), let p = placement.progress() {
                PlacementQuestionView(question: q, progress: p) { idx in
                    Task { await placement.answer(idx) }
                }
            } else {
                ProgressView()
            }
        case .finished:
            ProgressView()
        case .failed(let message):
            ScaffoldFailedView(message: message)
        }
    }
}

/// Owns the LessonViewModel for one lesson run.
struct LessonFlowView: View {
    @StateObject private var vm: LessonViewModel
    @State private var examplesWord: ExamplesContext?
    @State private var latestPerModeMastered: [String: Int]?
    let onExit: () -> Void
    private let client: BackendClient
    private let level: String
    private let mode: LessonMode

    struct ExamplesContext: Identifiable {
        let id = UUID()
        let word: String
        let level: String
    }

    init(client: BackendClient, level: String, mode: LessonMode = .readPickMeaning, onExit: @escaping () -> Void) {
        self.client = client
        self.level = level
        self.mode = mode
        self.onExit = onExit
        _vm = StateObject(wrappedValue: LessonViewModel(client: client, level: level, mode: mode))
    }

    var body: some View {
        Group {
            switch vm.phase {
            case .idle, .loading:
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large)
                    Text("Loading lesson…").foregroundStyle(.secondary)
                }
            case .answering(let state):
                if let q = state.currentQuestion {
                    questionView(for: q, state: state)
                } else { ProgressView() }
            case .revealing(let state, let outcome):
                AnswerFeedbackView(
                    question: state.questions[state.currentIndex],
                    outcome: outcome,
                    progress: state.progress,
                    isLast: state.currentIndex + 1 >= state.questions.count,
                    mode: mode,
                    typedAnswerEcho: vm.typedEchoForReveal,
                    onNext: { Task { await vm.next() } },
                    onShowExamples: {
                        examplesWord = ExamplesContext(word: state.questions[state.currentIndex].word, level: level)
                    }
                )
            case .completing:
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large)
                    Text("Scoring lesson…").foregroundStyle(.secondary)
                }
            case .summary(let summary):
                LessonSummaryView(
                    summary: summary,
                    mode: mode,
                    perModeMastered: latestPerModeMastered,
                    onStartAnother: onExit,
                    onBackHome: onExit
                )
                .task {
                    // Persist the mode just played so next launch defaults to it.
                    await vm.persistPreferredMode()
                    // Refresh per-mode counts so the strip reflects post-lesson state.
                    if let prog = try? await client.progress() {
                        latestPerModeMastered = prog.perModeMastered
                    }
                }
            case .failed(let message):
                ScaffoldFailedView(message: message)
            }
        }
        .task { await vm.start() }
        .sheet(item: $examplesWord) { context in
            ExamplesPanelView(
                viewModel: WordExamplesViewModel(client: client, word: context.word, level: context.level),
                onClose: { examplesWord = nil }
            )
        }
    }

    @ViewBuilder
    private func questionView(for q: LessonQuestion, state: LessonState) -> some View {
        switch mode {
        case .readPickMeaning:
            LessonQuestionView(
                question: q,
                progress: state.progress,
                onAnswer: { idx in Task { await vm.answer(idx) } },
                onSkip: { Task { await vm.skip() } },
                onExit: onExit
            )
        case .listenPickWord, .listenPickMeaning:
            ListeningLessonView(
                question: q,
                mode: mode,
                progress: state.progress,
                onAnswer: { idx in Task { await vm.answer(idx) } },
                onSkip: { Task { await vm.skip() } },
                onExit: onExit
            )
        case .listenType:
            ListeningLessonView(
                question: q,
                mode: mode,
                progress: state.progress,
                onAnswer: { idx in Task { await vm.answer(idx) } },
                onTypedAnswer: { text in Task { await vm.answerTyped(text) } },
                onSkip: { Task { await vm.skip() } },
                onExit: onExit
            )
        }
    }
}
