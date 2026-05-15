# Implementation Plan: Listening Modes

**Branch**: `002-listening-modes` | **Date**: 2026-05-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-listening-modes/spec.md`

## Summary

Add three listening-based lesson modes on top of the existing read-pick-meaning MVP:

1. `listen_pick_word` — hear English audio, pick the English word written
2. `listen_pick_meaning` — hear English audio, pick the Spanish meaning
3. `listen_type` — hear English audio, type the word (Levenshtein ≤ 1 tolerance)

This is also the **first** feature in a multi-feature arc (003 writing, 004 conjugation) and therefore lands the **shared "lesson modes" infrastructure**: per-(word, mode) mastery, mode selector on Home with cards + "Recomendado para ti" tag, mode-aware word selector, and reusable text-input UI.

## Technical Context

**Language/Version**:
- macOS app: Swift 5.9+ / SwiftUI (no changes)
- Backend: Node.js 20 LTS + TypeScript 5.x (no changes)

**Primary Dependencies**:
- No new dependencies. Reuses `AVSpeechSynthesizer` via `SpeechService.swift`, the existing zod schemas extended, and `better-sqlite3` for the migration.
- A small in-repo Levenshtein helper (~20 lines, no library needed) added to `LessonKit` and `backend/src/lessons/`.

**Storage**:
- `word_mastery` composite PK becomes `(userId, wordId, mode)`.
- `users.preferredMode TEXT NOT NULL DEFAULT 'read_pick_meaning'`.
- `lessons.mode TEXT NOT NULL DEFAULT 'read_pick_meaning'` for diagnostics + resume.

**Testing**:
- Backend: Vitest unit tests for Levenshtein, mode-aware word selector, per-mode mastery, modeRecommender. Integration tests for the extended `/v1/lessons` flow.
- App: XCTest for `ListeningLessonViewModel` and the typed-input variant (existing URLProtocol mock patterns).

**Target Platform**: macOS 14+ Apple Silicon (unchanged).

**Project Type**: Same as MVP — desktop app + embedded local service.

**Performance Goals**:
- Mode-card render in Home ≤ 50 ms after `/v1/progress` returns.
- Audio first-token (auto-play) ≤ 300 ms from question appear (SC-003).
- Levenshtein computation ≤ 1 ms per check (trivial at our string lengths).
- No regression on existing read-mode budgets.

**Constraints**:
- Offline-capable (TTS is local).
- Privacy-first (no new data leaves the device).
- Backward compatible: a missing `mode` field on `POST /v1/lessons` MUST default to `read_pick_meaning` (Principle V).

**Scale/Scope**:
- 300 curated words × 4 modes = up to 1,200 mastery rows per user.
- 3 user stories, 11 functional requirements.

## Constitution Check

Re-checked against project constitution v1.0.0. All principles addressed; no violations require entries in *Complexity Tracking*.

| Principle | How this feature satisfies it |
|-----------|------------------------------|
| **I. Test-First (NON-NEGOTIABLE)** | All new logic — Levenshtein, mode-aware selector, per-mode mastery, recommended-mode heuristic — gets a unit test before implementation. Contract tests for the new `mode` parameter and the extended `/v1/progress` shape. |
| **II. Library-First Architecture** | `LessonMode` enum added to the existing `LessonKit` Swift package. Levenshtein lives in pure Swift in `LessonKit` (reused by F003 later). Backend `wordSelector` extended via a `mode` parameter, not duplicated. |
| **III. Simplicity & YAGNI** | No new external deps. No mode-unlock state machine. No SRS. "Recomendado para ti" is just `argmax(pending_per_mode)` with a recency tiebreaker. |
| **IV. Observability** | Each lesson logs `mode` in its structured log line + on the `lessons` row. Mode selector picks are logged. |
| **V. Versioning & Breaking Changes** | `mode` is OPTIONAL on `POST /v1/lessons`. Absent → `read_pick_meaning` (backward compatible). Migration is additive (`0003_lesson_modes.sql`). SemVer bump to `1.2.0`. |
| **VI. Security & Privacy** | No new external services. TTS is local. No mode-related telemetry. The `preferredMode` column is a plain string. |
| **VII. Accessibility** | Mode cards have VoiceOver labels (e.g. `"Modo Escuchar. 12 palabras por dominar. Recomendado para ti."`). The audio question has a visible 🔊 with `S` shortcut. Typed-input field is keyboard accessible. |
| **VIII. Performance Budgets** | New perf benches: mode-card render time, audio-first-token time. Existing budgets re-verified. |

**Gate: PASS** for Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/002-listening-modes/
├── plan.md              # This file
├── research.md          # Phase 0 — small (most decisions inherited from 001)
├── data-model.md        # Delta over 001
├── contracts/
│   └── openapi-delta.yaml
└── tasks.md             # Phase 2 (produced by /speckit-tasks)
```

### Source code (delta over 001)

```text
app/
├── GramartEnglish/Sources/Features/
│   ├── Lesson/
│   │   ├── ListeningLessonView.swift        ← NEW (audio-only stimulus)
│   │   ├── TypedAnswerInputView.swift       ← NEW (text field used by listen_type)
│   │   └── ModeCard.swift                   ← NEW (Home card per mode)
│   └── ... (existing files unchanged except wiring in RootView)
└── Packages/LessonKit/Sources/LessonKit/
    ├── LessonMode.swift                     ← NEW (enum + helpers)
    └── Levenshtein.swift                    ← NEW (pure helper)

backend/src/
├── lessons/
│   ├── modeRecommender.ts                   ← NEW (picks "Recomendado para ti")
│   ├── levenshtein.ts                       ← NEW (typo tolerance)
│   └── wordSelector.ts                      ← EXTENDED (mode parameter)
├── store/migrations/
│   └── 0003_lesson_modes.sql                ← NEW
├── store/
│   ├── masteryRepository.ts                 ← EXTENDED (mode on PK)
│   └── userRepository.ts                    ← EXTENDED (preferredMode column)
└── routes/
    ├── lessons.ts                           ← `mode` body param + dispatch
    └── progress.ts                          ← per-mode breakdown
```

**Structure decision**: Reuse the existing two-tier layout. Everything new slots into existing folders. The shared infra introduced here (LessonMode, Levenshtein, ModeCard, TypedAnswerInputView, modeRecommender, mode-aware wordSelector) is what features 003 and 004 will reuse.

## Phases

### Phase 0 — Research

Decisions captured in `research.md`:

1. **Levenshtein implementation**: pure Swift + pure TypeScript, in-repo, ~20 LOC each. No library. Rationale: minimal surface area, supply-chain-free, trivially testable.
2. **"Recomendado para ti" heuristic**: `argmax(pending_per_mode)` with `least-recently-used` tiebreaker. Explainable, deterministic, zero new data.
3. **Audio caching**: none. `AVSpeechSynthesizer` re-synthesizes in < 50 ms per word; caching adds complexity for marginal gain.
4. **Mode icons**: SF Symbols — `book` (read), `ear` (listen), `pencil` (write), `arrow.triangle.2.circlepath` (conjugate).

### Phase 1 — Design & Contracts

1. **Data model delta** (`data-model.md`):
   - `LessonMode` enum: `read_pick_meaning | listen_pick_word | listen_pick_meaning | listen_type`. (Verb modes added in F004.)
   - `word_mastery` composite PK becomes `(userId, wordId, mode)`. Existing rows migrated with `mode = 'read_pick_meaning'`.
   - `users.preferredMode TEXT NOT NULL DEFAULT 'read_pick_meaning'`.
   - `lessons.mode TEXT NOT NULL DEFAULT 'read_pick_meaning'`.

2. **Contracts delta** (`contracts/openapi-delta.yaml`):
   - `POST /v1/lessons` body: add optional `mode: LessonMode`.
   - `GET /v1/progress` response: add `perModeMastered` map and `recommendedMode`.
   - `POST /v1/lessons/{id}/answers`: accept `typedAnswer: string` for `listen_type` (alternative to `optionIndex`).
   - `AnswerResponse`: add `typedAnswerEcho: string?` so reveal can show user's typed vs canonical.

3. **Agent context update**: `CLAUDE.md` points to this plan and notes that mastery is now per-mode.

### Phase 2 — Tasks (`/speckit-tasks`)

Expected task groups:

- **Setup**: migration 0003, `LessonMode` enum (Swift + TS), Levenshtein helpers, ModeCard view shell.
- **Foundational**: mode-aware mastery repo + wordSelector (tests first); route updates; modeRecommender.
- **US1 (P1)** `listen_pick_word`: end-to-end including `ListeningLessonView` + ModeCard on Home + auto-play.
- **US2 (P2)** `listen_pick_meaning`: same view with Spanish options.
- **US3 (P3)** `listen_type`: `TypedAnswerInputView` + Levenshtein grading + side-by-side reveal.
- **Polish**: mastery badges by mode, perf benches, accessibility audit pass.

## Complexity Tracking

> No constitution violations require justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | — | — |
