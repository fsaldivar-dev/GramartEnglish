# Implementation Plan: Vocabulary Lesson MVP

**Branch**: `001-vocabulary-lesson-mvp` | **Date**: 2026-05-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-vocabulary-lesson-mvp/spec.md`

## Summary

Build the GramartEnglish MVP: a native macOS app that delivers vocabulary lessons as 10-question multiple-choice quizzes drawn from curated CEFR word lists (A1–C2). A first-run placement test (~10 mixed-level questions) estimates the user's CEFR level. The macOS app launches a Node.js backend as a supervised child process; the backend runs an HTTP API, a local SQLite store, and a Retrieval-Augmented Generation (RAG) pipeline that grounds Ollama-generated **usage examples** and **contextual definitions** in the curated corpus. The product is fully local, privacy-first (no login, no telemetry, no data leaves the device), and targets macOS 14+ on Apple Silicon (M1+) with 16 GB of RAM.

## Technical Context

**Language/Version**:
- macOS app: **Swift 5.9+** with **SwiftUI** (AppKit only where SwiftUI is insufficient).
- Backend: **Node.js 20 LTS** with **TypeScript 5.x**.

**Primary Dependencies**:
- macOS app: SwiftUI, Combine, `Foundation.Process` for child-process supervision, `URLSession` for HTTP.
- Backend: `fastify` (HTTP), `better-sqlite3` (storage), `hnswlib-node` (local vector index), `ollama` JS client, `pino` (structured logging), `zod` (validation).

**Storage**:
- Application data (users, lessons, mastery, RAG sources metadata): **SQLite** via `better-sqlite3`, located under `~/Library/Application Support/GramartEnglish/`.
- Vector index for RAG: HNSW index files alongside SQLite (`rag.index`).
- Embeddings: generated via Ollama (`nomic-embed-text`), persisted alongside source rows.

**Testing**:
- macOS app: **XCTest** for unit tests + Swift Package–level tests for `LessonKit` and `BackendClient`. UI tests with `XCUITest` for the placement and lesson flows.
- Backend: **Vitest** for unit tests; `supertest` for HTTP contract tests; integration tests run against a real local SQLite + a stubbed Ollama for determinism, plus a small "smoke" suite against a real Ollama in CI when available.

**Target Platform**: macOS 14 (Sonoma) or later, Apple Silicon (M1+), 16 GB RAM minimum. Distribution: signed, notarized `.app` bundle that embeds the Node.js runtime and backend code.

**Project Type**: Desktop application + embedded local service (`mobile + API`-style split adapted to macOS).

**Performance Goals**:
- Cold app launch to first question visible: ≤ 2.0 s on M1 / 16 GB (SC-003).
- Lesson screen transition: ≤ 150 ms.
- LLM-grounded answer first token (Ollama via RAG): ≤ 1.5 s (SC-004).
- Backend non-LLM endpoint p95 latency: ≤ 200 ms.

**Constraints**:
- Offline-capable after install; no calls to non-local services.
- Privacy-first: no login, no telemetry, no analytics.
- No LLM cloud providers (constitution).
- Embedded Node.js binary must be < 80 MB compressed in the app bundle.

**Scale/Scope**:
- Single-user per install (no multi-user).
- 6 CEFR levels × ≥ 50 curated words = ≥ 300 vocabulary entries at MVP launch.
- 3 user stories (Placement / Lesson / AI examples), 19 functional requirements.

## Constitution Check

Re-checked against [.specify/memory/constitution.md](../../.specify/memory/constitution.md) (v1.0.0). All 8 principles are addressed by the plan; no violations require entries in **Complexity Tracking**.

| Principle | How the plan satisfies it |
|-----------|---------------------------|
| **I. Test-First (NON-NEGOTIABLE)** | Tasks in `tasks.md` will order tests before implementation for every backend route, the word-selection algorithm, the placement-test scorer, RAG retrieval, the child-process supervisor in Swift, and the mastery state machine. CI runs Vitest + XCTest before any merge. |
| **II. Library-First Architecture** | Backend split into independent TypeScript modules (`lessons`, `rag`, `llm`, `store`, `observability`) each with its own public interface and tests. macOS side uses Swift Packages: `LessonKit` (state machine + mastery), `BackendClient` (typed API client) — both reusable for a future iOS port. |
| **III. Simplicity & YAGNI** | No GraphQL, no event bus, no auth, no multi-tenant code paths. Word-selection uses the 50/30/20 mix from the spec, not full SRS. RAG uses a single local HNSW file, not a vector DB service. |
| **IV. Observability** | `pino` produces JSON logs on the backend; each HTTP request gets a `correlation-id` propagated from the macOS client header, carried through to Ollama calls and back. macOS app writes a rotating log file under `~/Library/Logs/GramartEnglish/`. AI generations record model, prompt-hash, RAG source IDs, latency. |
| **V. Versioning & Breaking Changes** | All HTTP paths prefixed `/v1/`. SQLite schema versioned via `PRAGMA user_version`. RAG index file carries a `schemaVersion` header; mismatched indexes are detected at boot and rebuilt. App and backend share a single SemVer in `version.json`. |
| **VI. Security & Privacy** | No login, no PII. SQLite stored with user permissions; backend binds to `127.0.0.1` on a random ephemeral port; the port is passed to the macOS app via stdout handshake, never advertised on the network. No outbound HTTP. App is sandboxed and signed. |
| **VII. Accessibility** | SwiftUI views built with `accessibilityLabel`/`accessibilityHint`; keyboard shortcuts for "Select option 1–4", "Next", "Skip"; respects Dynamic Type and Reduce Motion. Accessibility audit checklist appended to each UI-related task in `tasks.md`. |
| **VIII. Performance Budgets** | Plan includes a `perf/` test bench that measures cold-launch, screen transitions, first-token latency, and p95 of `/v1/lessons` on every merge to `main`. Regressions block merge per principle VIII. |

**Gate: PASS** for Phase 0. To be re-evaluated after Phase 1 design.

## Project Structure

### Documentation (this feature)

```text
specs/001-vocabulary-lesson-mvp/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (HTTP contracts + Swift type contracts)
│   ├── openapi.yaml
│   └── README.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (already produced)
└── tasks.md             # Phase 2 output (NOT produced by /speckit-plan)
```

### Source Code (repository root)

```text
app/                                       # Swift / SwiftUI macOS app
├── GramartEnglish.xcodeproj/
├── GramartEnglish/
│   ├── Sources/
│   │   ├── App/                           # @main App, scene, root navigation
│   │   ├── Features/
│   │   │   ├── Onboarding/                # Placement test screens + view models
│   │   │   ├── Lesson/                    # Quiz UI + view models
│   │   │   ├── Settings/                  # Level override, accessibility prefs
│   │   │   └── BackendBridge/             # Child-process supervisor + handshake
│   │   ├── Shared/
│   │   │   ├── Accessibility/
│   │   │   └── Logging/                   # Local rotating file logger
│   │   └── Resources/                     # Bundled backend binaries + CEFR data
│   └── Tests/                             # XCTest unit + XCUITest
└── Packages/                              # Local Swift packages
    ├── LessonKit/                         # State machine, mastery tracker (pure Swift)
    │   ├── Sources/LessonKit/
    │   └── Tests/LessonKitTests/
    └── BackendClient/                     # Typed HTTP client (URLSession)
        ├── Sources/BackendClient/
        └── Tests/BackendClientTests/

backend/                                   # Node.js / TypeScript service
├── package.json
├── tsconfig.json
├── src/
│   ├── server.ts                          # Fastify bootstrap + port handshake
│   ├── routes/                            # HTTP routes (v1)
│   │   ├── health.ts
│   │   ├── levels.ts
│   │   ├── placement.ts
│   │   ├── lessons.ts
│   │   └── words.ts
│   ├── lessons/                           # Word selection (50/30/20 mix), scoring
│   ├── rag/                               # Ingestion, retrieval, grounding
│   ├── llm/                               # Ollama adapter, prompt builders
│   ├── store/                             # SQLite repositories + migrations
│   ├── observability/                     # pino logger, correlation-id plugin
│   └── domain/                            # Pure types shared across modules
├── tests/
│   ├── unit/
│   ├── contract/                          # supertest against OpenAPI contracts
│   └── integration/                       # Real SQLite + stub Ollama
└── perf/                                  # Latency benches

data/                                      # Curated CEFR corpus (versioned)
└── cefr/
    ├── a1.json
    ├── a2.json
    ├── b1.json
    ├── b2.json
    ├── c1.json
    ├── c2.json
    └── examples/                          # Canonical example sentences per word

scripts/
├── package-backend.sh                     # Bundle Node.js + backend into .app
└── ingest-cefr.ts                         # One-shot RAG ingestion
```

**Structure Decision**: Two-tier layout — `app/` for the SwiftUI client (with two local Swift Packages for testable libraries) and `backend/` for the embedded Node.js/TypeScript service. The `data/` directory holds the curated CEFR corpus that the RAG pipeline ingests at first launch. This split honors **Library-First** (modules with independent tests) and **Simplicity** (no extra microservices). It also leaves a natural seam for a future iOS port: the same `backend/` and `Packages/` can be reused.

## Complexity Tracking

> No violations of Constitution Check. This section is intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | (none) | (none) |
