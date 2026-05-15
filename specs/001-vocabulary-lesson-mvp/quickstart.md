# Quickstart: Vocabulary Lesson MVP

This is the developer onboarding for working on the MVP. It covers prerequisites, building the macOS app and the embedded backend, running tests, and validating the feature end-to-end.

## Prerequisites

- macOS 14 (Sonoma) or later on Apple Silicon (M1+).
- **Xcode 15.4+** with Command Line Tools.
- **Node.js 20 LTS** (via `nvm`, `mise`, or the official installer).
- **Ollama** installed (`brew install ollama` or the `.pkg` from ollama.com).
- 16 GB of RAM (LLM model weights need ~5 GB).
- ~10 GB of free disk space.

One-time Ollama setup:

```bash
ollama serve &                        # if not already running as a service
ollama pull llama3.1:8b-instruct-q4_K_M
ollama pull nomic-embed-text
```

## Repository layout

```
app/        # SwiftUI macOS app + local Swift Packages (LessonKit, BackendClient)
backend/    # Node.js + TypeScript embedded service
data/       # Curated CEFR corpus
scripts/    # Build + ingestion utilities
specs/      # Spec-driven artifacts (this feature)
```

## Backend (Node.js)

```bash
cd backend
npm ci
npm run build           # tsc + esbuild bundle
npm test                # Vitest unit + contract tests (stubbed Ollama)
npm run dev             # ts-node with file-watch on http://127.0.0.1:0
```

First-time data ingestion (one-shot, idempotent):

```bash
npm run ingest          # reads data/cefr/*.json, writes SQLite + hnsw index
```

The backend prints a JSON handshake line to stdout when ready:

```text
{"port":56781,"pid":42,"version":"1.0.0"}
```

In dev, use that port to curl the API; in production, the macOS app reads it automatically.

## macOS app (Xcode)

```bash
open app/GramartEnglish.xcodeproj
```

Build & run with `⌘R`. The app launches the bundled backend as a child process. On first launch you will see:

1. Welcome screen → "Start placement test" (User Story 0).
2. ~12 mixed-level questions.
3. Estimated CEFR level shown.
4. First 10-question vocabulary lesson (User Story 1).
5. Tap "Show examples" on any word to exercise the RAG+LLM path (User Story 2).

## Running tests

```bash
# Backend
cd backend && npm test

# Swift packages (headless)
cd app && swift test --package-path Packages/LessonKit
cd app && swift test --package-path Packages/BackendClient

# Xcode app + UI tests
xcodebuild -project app/GramartEnglish.xcodeproj \
  -scheme GramartEnglish \
  -destination 'platform=macOS' test
```

## Acceptance walkthrough (mirrors `spec.md`)

To manually verify each user story passes before requesting review:

| User Story | What to do | What you should see |
|------------|------------|---------------------|
| **US 0** — Placement | Fresh install → first launch | Welcome + placement test + estimated level |
| **US 1** — Lesson (P1) | Start a lesson at the estimated level | 10 multiple-choice questions, score at the end |
| **US 2** — RAG + LLM (P2) | Tap "Show examples" on a missed word | 2–3 example sentences containing the word in < 1.5 s to first token |
| **US 2 (fallback)** | Quit Ollama, retry "Show examples" | Banner "AI examples unavailable" + canonical example shown |
| **US 3** — Persistence (P3) | Complete a lesson, quit, relaunch | Last-lesson score shown; mastered words tracked |

## Performance budgets (Constitution VIII)

| Budget | How to measure |
|--------|----------------|
| Cold app launch ≤ 2.0 s | `xcrun` instruments or the `perf/launch.swift` harness |
| Lesson transition ≤ 150 ms | `perf/transitions.swift` |
| LLM first token ≤ 1.5 s | `backend/perf/llm-first-token.ts` |
| Backend non-LLM p95 ≤ 200 ms | `backend/perf/api-p95.ts` |

A regression in any budget blocks merge.

## Troubleshooting

- **Backend won't start**: check `~/Library/Logs/GramartEnglish/backend-*.log`. Usually a port-clash (handled automatically) or a missing native module (`npm rebuild better-sqlite3 hnswlib-node`).
- **Ollama times out**: ensure `ollama serve` is running and both models are pulled.
- **Index schema mismatch**: delete `~/Library/Application Support/GramartEnglish/rag.index`; the backend rebuilds it from SQLite on next launch.
