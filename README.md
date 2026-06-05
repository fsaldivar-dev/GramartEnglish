<div align="center">
  <img src=".github/assets/app-icon.png" alt="GramartEnglish app icon" width="160" height="160" />

  # GramartEnglish

  A native macOS app that helps English learners build vocabulary at their own CEFR level (A1–C2), with optional AI-generated example sentences grounded in a curated local corpus via a local LLM (Ollama).

  **Latest release** · [v1.4.0](https://github.com/fsaldivar-dev/GramartEnglish/releases/latest)  ·  **Status**: MVP development. Spec-driven via [spec-kit](https://github.com/github/spec-kit).
</div>

## Principles

GramartEnglish is built under a written project constitution. The full ratified rules live in [.specify/memory/constitution.md](.specify/memory/constitution.md), but the headline is:

- **Test-First** (non-negotiable)
- **Library-First** architecture
- **Simplicity & YAGNI**
- **Observability** (structured logs + correlation id end-to-end)
- **Versioning** (SemVer, schema versions, `/v1` API prefix)
- **Security & Privacy** — no login, no telemetry, no data leaves the device
- **Accessibility** — VoiceOver, keyboard nav, Dynamic Type, Increase Contrast
- **Performance budgets** (≤ 2 s cold launch, ≤ 1.5 s LLM first token)

## What's new in v1.4 — Adaptive Placement (F005)

The placement test no longer asks 24 fixed questions across all 6 levels. Instead it adapts: an optional self-report screen anchors your starting level ("Nunca / Un poco / Bastante"), then the test asks one question at a time and ramps difficulty up or down based on your answers, finishing in 12–30 items. A user who can't read past A1 now lands at A1 instead of being randomly classified as C1. The Settings level override is unchanged and continues to constrain lesson selection end-to-end — pinned by a regression test added in this release. See [specs/005-adaptive-placement/](specs/005-adaptive-placement/).

## Active feature

The current feature is `002-listening-modes` (built on top of `001-vocabulary-lesson-mvp`). Design lives under [specs/002-listening-modes/](specs/002-listening-modes/):

- [spec.md](specs/002-listening-modes/spec.md) — listening-modes user stories, requirements, success criteria
- [plan.md](specs/002-listening-modes/plan.md) — implementation plan
- [data-model.md](specs/002-listening-modes/data-model.md) — migration 0003 (per-mode mastery)
- [contracts/openapi-delta.yaml](specs/002-listening-modes/contracts/openapi-delta.yaml) — additions on top of v1.1 contract
- [tasks.md](specs/002-listening-modes/tasks.md) — 63 dependency-ordered tasks
- [design/a11y-audit.md](specs/002-listening-modes/design/a11y-audit.md) — accessibility checklist for the new surfaces

The MVP foundation (still authoritative for unchanged areas) is documented under [specs/001-vocabulary-lesson-mvp/](specs/001-vocabulary-lesson-mvp/).

## Lesson modes

Feature 002 introduces four lesson modes, each tracked as an **independent** mastery axis. Mastering "weather" by reading does NOT mark it mastered by ear — they're separate skills.

| Mode | Icon | What you do | Status |
|---|---|---|---|
| `read_pick_meaning` | 📖 | See the English word in context, pick the Spanish meaning | Shipped (F001) |
| `listen_pick_word` | 👂 | Hear audio, pick the English word from 4 options | Shipped (F002) |
| `listen_pick_meaning` | 👂 | Hear audio, pick the Spanish meaning from 4 options | Shipped (F002) |
| `listen_type` | 🎧 | Hear audio, type the word (typos within Levenshtein ≤ 1 accepted) | Shipped (F002) |
| `write_pick_word` | ✏️ | See the Spanish meaning, pick the English word from 4 options | Shipped (F003) |
| `write_type_word` | ✏️ | See the Spanish meaning, type the English word (Levenshtein ≤ 1 + hint button) | Shipped (F003) |
| `write_fill_gaps` | ✏️ | See Spanish + masked English (e.g. `w__th_r`), type the missing letters | Próximamente (v1.4) |
| `conjugate_pick_form` | 🔁 | Future: verb conjugation drills | Próximamente (F004) |

Per-mode mastery is surfaced in three places: the Home cards (pending counts + "Recomendado para ti" tag), the post-lesson summary (per-mode badge strip), and the **Mis palabras** screen.

**Read vs. Write modes** train the same vocabulary in opposite directions: read modes test recognition (you see English, prove you know its meaning), write modes test active recall (you see Spanish, prove you can produce the English). A word can be mastered in `read_pick_meaning` and still pending in `write_type_word` — that's the "I recognize but can't produce" gap that productive practice closes.

## Repository layout

```
.specify/         Spec-kit configuration, memory, templates
app/              SwiftUI macOS app (SwiftPM)
  GramartEnglish/ Executable target
  Packages/       Local Swift packages
    LessonKit/      Pure-Swift lesson state machine
    BackendClient/  Typed HTTP client
backend/          Embedded Node.js + TypeScript backend
data/cefr/        Curated vocabulary corpus (CEFR-leveled)
scripts/          Build + tooling
specs/            Feature design artifacts (spec-driven)
```

## Tooling

- macOS 14 (Sonoma) or later, Apple Silicon (M1+), 16 GB RAM
- Xcode 15.4+ (or Xcode that opens SwiftPM `Package.swift`)
- Node.js 20 LTS (NOT odd-numbered "Current" releases — those break native modules)
- pnpm 9.x (npm and yarn are blocked by a `preinstall` script)
- Ollama with `nomic-embed-text` and a chat model (e.g. `qwen2.5:7b` or `llama3.1:8b-instruct-q4_K_M`)

Quick setup:

```bash
# Node 20 LTS
brew install mise && mise use --global node@20

# pnpm 9 via Corepack
corepack enable
corepack prepare pnpm@9.12.0 --activate

# Ollama models
brew install ollama
ollama serve &
ollama pull nomic-embed-text
ollama pull qwen2.5:7b   # or your preferred chat model
```

## Run

```bash
# Terminal 1 — backend
cd backend
pnpm install
GRAMART_CHAT_MODEL=qwen2.5:7b pnpm run dev
# Backend prints a single handshake line: {"port":N,"pid":N,"version":"x.y.z"}

# Terminal 2 — app
cd app/GramartEnglish
GRAMART_BACKEND_URL=http://127.0.0.1:<PORT> swift run
```

First launch flow: Welcome → Placement test (~12 questions) → estimated level → Home → first lesson → score.

## Test

```bash
cd backend && pnpm test                              # backend (vitest)
cd app/Packages/LessonKit && swift test              # state machine
cd app/Packages/BackendClient && swift test          # HTTP client
cd app/GramartEnglish && swift test                  # view models
```

## Spec-driven workflow

When evolving the project, use the slash commands provided by spec-kit:

1. `/speckit-constitution` — amend project rules (rare)
2. `/speckit-specify` — describe a new feature in natural language
3. `/speckit-clarify` — resolve ambiguities (optional)
4. `/speckit-plan` — produce the implementation plan
5. `/speckit-tasks` — generate the dependency-ordered task list
6. `/speckit-analyze` — cross-check spec, plan, tasks (optional)
7. `/speckit-implement` — execute the tasks

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full developer workflow.

## License & sources

- Vocabulary corpus assembled from openly licensed sources (CEFR-J Wordlist CC BY-SA 4.0, English Vocabulary Profile, Tatoeba CC BY 2.0 FR). Definitions and examples are author-written or paraphrased. See [data/cefr/README.md](data/cefr/README.md) for provenance per source.
