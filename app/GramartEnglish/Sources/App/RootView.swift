import SwiftUI
import BackendClient
import LessonKit
import os

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
                    onStart: {
                        // v1.4 F005: send the user to the self-report anchor
                        // screen first; the test only starts after they pick
                        // (or skip). PlacementViewModel begins in .selfReport.
                        placement.reset()
                        phase = .placement
                    },
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
            case .lesson(let level, let mode, let resumeId):
                LessonFlowView(
                    client: client,
                    level: level,
                    mode: mode,
                    resumeId: resumeId,
                    onExit: { Task { await goHome(level: level) } },
                    // F010 Item 3 (v1.11.0). Resume CTA from LessonSummaryView
                    // — phase-hop straight into the leftover lesson rather
                    // than routing through Home.
                    onResumeLeftover: { snap in
                        // F010 v1.11.0 patch — same defensive pattern as
                        // `initialPhase`: if the snapshot's mode raw value
                        // doesn't decode to a known LessonMode, refuse to
                        // route silently into `readPickMeaning` (Priya's
                        // blocker). Drop the snapshot and bounce to Home.
                        if let resolvedMode = LessonMode(rawValue: snap.mode) {
                            phase = .lesson(level: snap.level, mode: resolvedMode, resumeId: snap.lessonId)
                        } else {
                            Self.resumeLogger.warning(
                                "Discarding snapshot with unknown mode rawValue=\(snap.mode, privacy: .public); routing to Home."
                            )
                            LessonStateStore.shared.clear()
                            phase = .home(level: level)
                        }
                    }
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
        // F007 (v1.8.0) + F010 v1.11.0 patch. Snapshot recovery is delegated
        // to a static helper so the unknown-mode path (Priya's blocker —
        // a stored rawValue that no longer decodes to a known LessonMode
        // used to silently coerce into `readPickMeaning`) is unit-testable
        // without driving the SwiftUI body or the backend client.
        if let resumed = Self.recoverResumePhase(
            snapshot: LessonStateStore.shared.load(),
            resumableLessonId: home.progress?.resumable?.lessonId,
            store: LessonStateStore.shared,
            logger: Self.resumeLogger
        ) {
            phase = resumed
            return
        }
        if let p = home.progress, p.lessonsCompleted > 0 || p.resumable != nil {
            phase = .home(level: p.currentLevel)
        } else {
            phase = .welcome
        }
    }

    /// F010 v1.11.0 patch (Priya blocker). Pure resolver for the snapshot
    /// recovery path on launch. Returns:
    /// - `.lesson(...)` when the local snapshot matches a server-resumable
    ///   lesson AND its `mode` rawValue decodes to a known `LessonMode`.
    /// - `nil` when there is no snapshot, when the snapshot is stale (server
    ///   has nothing to resume into / different lessonId), or when the mode
    ///   rawValue is unknown.
    ///
    /// The unknown-mode case used to silently coerce to `readPickMeaning` —
    /// the wrong mode, the wrong mastery accounting, no signal anything is
    /// broken. We now log a warning, clear the snapshot, and return nil so
    /// the caller routes to `.home` as if no snapshot existed.
    static func recoverResumePhase(
        snapshot: LessonStateSnapshot?,
        resumableLessonId: String?,
        store: LessonStateStore,
        logger: Logger
    ) -> Phase? {
        guard let snap = snapshot else { return nil }
        guard let lid = resumableLessonId, lid == snap.lessonId else {
            store.clear()
            return nil
        }
        guard let mode = LessonMode(rawValue: snap.mode) else {
            logger.warning(
                "Discarding snapshot with unknown mode rawValue=\(snap.mode, privacy: .public); routing to Home."
            )
            store.clear()
            return nil
        }
        return .lesson(level: snap.level, mode: mode, resumeId: snap.lessonId)
    }

    /// F010 v1.11.0 patch. Shared logger for snapshot-recovery warnings;
    /// keeps the `subsystem`/`category` consistent with `FileLogger`.
    static let resumeLogger = Logger(subsystem: "com.gramart.english", category: "ResumeRecovery")

    private func goHome(level: String) async {
        await home.refresh()
        phase = .home(level: home.progress?.currentLevel ?? level)
    }

    @ViewBuilder
    private var placementBody: some View {
        switch placement.state {
        case .selfReport:
            PlacementSelfReportView { picked in
                Task { await placement.start(selfReport: picked) }
            }
        case .loading, .submitting:
            VStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text(placement.state == .submitting ? "Scoring…" : "Calibrando…")
                    .foregroundStyle(.secondary)
            }
        case .question:
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
    /// F010 Item 3 (v1.11.0). Snapshot probed when the summary appears
    /// — if a DIFFERENT in-flight lesson is still on disk, we surface
    /// the "Continuar lección anterior" CTA on the summary screen.
    @State private var leftoverSnapshot: LessonStateSnapshot?
    let onExit: () -> Void
    /// F010 Item 3 (v1.11.0). Routes the resume CTA back through
    /// RootFlowView so the phase flips to `.lesson(..., resumeId: …)`
    /// with the leftover snapshot's identifiers.
    let onResumeLeftover: (LessonStateSnapshot) -> Void
    private let client: BackendClient
    private let level: String
    private let mode: LessonMode
    /// F007 patch (v1.8.0). When non-nil, `.task` calls `vm.start(resumeId:)`
    /// instead of a fresh `start()`, so the user returns to the in-flight
    /// lesson identified by the local snapshot rather than starting a brand
    /// new lesson (the original bug).
    private let resumeId: String?
    /// F007 banner state. Set true on first appear when the VM has a
    /// `resumeBanner` payload; the banner auto-dismisses after 3s or on
    /// first user interaction.
    @State private var showingResumeBanner = false

    struct ExamplesContext: Identifiable {
        let id = UUID()
        let word: String
        let level: String
    }

    init(
        client: BackendClient,
        level: String,
        mode: LessonMode = .readPickMeaning,
        resumeId: String? = nil,
        onExit: @escaping () -> Void,
        onResumeLeftover: @escaping (LessonStateSnapshot) -> Void = { _ in }
    ) {
        self.client = client
        self.level = level
        self.mode = mode
        self.resumeId = resumeId
        self.onExit = onExit
        self.onResumeLeftover = onResumeLeftover
        _vm = StateObject(wrappedValue: LessonViewModel(client: client, level: level, mode: mode))
    }

    var body: some View {
        ZStack(alignment: .top) {
            content
            if showingResumeBanner, let banner = vm.resumeBanner {
                resumeBannerView(banner: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .task { await vm.start(resumeId: resumeId) }
        .onChange(of: vm.resumeBanner) { _, newValue in
            if newValue != nil {
                showingResumeBanner = true
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation { showingResumeBanner = false }
                }
            }
        }
        .sheet(item: $examplesWord) { context in
            ExamplesPanelView(
                viewModel: WordExamplesViewModel(client: client, word: context.word, level: context.level),
                onClose: { examplesWord = nil }
            )
        }
    }

    @ViewBuilder
    private func resumeBannerView(banner: LessonViewModel.ResumeBanner) -> some View {
        // F007 patch (v1.8.0). Marisol + Priya: dropping a returning learner
        // into a question with zero context is "trabajo a medias" and breaks
        // the Fogg Trigger re-prime. Show a transient strip naming where they
        // are + a "start fresh" escape hatch.
        let copy = "Continuando donde quedaste · pregunta \(banner.currentQuestionIndex + 1) de \(banner.totalCount)"
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.tint)
            Text(copy)
                .font(.callout)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Empezar de nuevo") {
                showingResumeBanner = false
                LessonStateStore.shared.clear()
                vm.resumeBanner = nil
                Task { await vm.start(resumeId: nil) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityHint("Descarta el avance y comienza una lección nueva")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // F010 (v1.11.0). Token sweep — 10pt rounds to Radius.md (12).
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.md))
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch vm.phase {
            case .idle, .loading:
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large)
                    Text("Loading lesson…").foregroundStyle(.secondary)
                }
            case .answering(let state):
                if let intro = vm.pendingIntro {
                    // F006 (v1.7.0): "Conoce el verbo" micro-card before the
                    // first conjugate_pick_form question per verb.
                    VerbIntroCard(intro: intro, onDismiss: { vm.dismissVerbIntro() })
                } else if let q = state.currentQuestion {
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
                    resumableSnapshot: leftoverSnapshot,
                    // F008 Item 4 (v1.9.0). Priya flagged: both buttons used
                    // to wire to `onExit`, which routed the learner through
                    // Home and re-cost a click to start the next lesson —
                    // the "siguiente lección" CTA must commit to a new
                    // lesson directly. We now reset the VM and re-call
                    // `vm.start()` for "Empezar otra"; "Volver al inicio"
                    // keeps the original exit path.
                    onStartAnother: {
                        latestPerModeMastered = nil
                        Task { await vm.start(resumeId: nil) }
                    },
                    onBackHome: onExit,
                    onResumeLesson: {
                        guard let snap = leftoverSnapshot else { return }
                        onResumeLeftover(snap)
                    }
                )
                .task {
                    // Persist the mode just played so next launch defaults to it.
                    await vm.persistPreferredMode()
                    // Refresh per-mode counts so the strip reflects post-lesson state.
                    if let prog = try? await client.progress() {
                        latestPerModeMastered = prog.perModeMastered
                    }
                    // F010 Item 3 (v1.11.0). Probe the snapshot store; the
                    // CTA only fires when the snapshot is for a DIFFERENT
                    // lesson than the one we just finished (the store
                    // visibility predicate lives on LessonSummaryView).
                    leftoverSnapshot = LessonStateStore.shared.load()
                }
            case .failed(let message):
                ScaffoldFailedView(message: message)
            }
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
        case .writePickWord:
            WritingLessonView(
                question: q,
                mode: mode,
                progress: state.progress,
                onAnswer: { idx in Task { await vm.answer(idx) } },
                onSkip: { Task { await vm.skip() } },
                onExit: onExit
            )
        case .writeTypeWord, .writeFillGaps:
            WritingLessonView(
                question: q,
                mode: mode,
                progress: state.progress,
                onTypedAnswer: { text, hintUsed in
                    Task { await vm.answerTyped(text, hintUsed: hintUsed) }
                },
                onSkip: { Task { await vm.skip() } },
                onExit: onExit
            )
        case .conjugatePickForm:
            ConjugationLessonView(
                question: q,
                progress: state.progress,
                onAnswer: { idx in Task { await vm.answer(idx) } },
                onSkip: { Task { await vm.skip() } },
                onExit: onExit
            )
        }
    }
}
