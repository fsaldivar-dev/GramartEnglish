<!--
SYNC IMPACT REPORT
==================
Version change: (template/unversioned) → 1.0.0
Bump rationale: MAJOR — Initial ratification of the project constitution
                (no prior versioned constitution existed).

Modified principles:
  - [PRINCIPLE_1_NAME] → I. Test-First (NON-NEGOTIABLE)
  - [PRINCIPLE_2_NAME] → II. Library-First Architecture
  - [PRINCIPLE_3_NAME] → III. Simplicity & YAGNI
  - [PRINCIPLE_4_NAME] → IV. Observability
  - [PRINCIPLE_5_NAME] → V. Versioning & Breaking Changes
Added principles (beyond template's default 5):
  - VI. Security & Privacy
  - VII. Accessibility
  - VIII. Performance Budgets

Added sections:
  - Technology & Platform Constraints (Section 2)
  - Development Workflow & Quality Gates (Section 3)

Removed sections: none

Templates requiring updates:
  - ✅ .specify/templates/plan-template.md — Constitution Check gate references
    will be derived from these principles at /speckit-plan time (no edits needed
    now; gate is principle-driven and resolved per-feature).
  - ✅ .specify/templates/spec-template.md — no structural changes required.
  - ✅ .specify/templates/tasks-template.md — task categories already cover
    test-first, observability, and contract testing.
  - ⚠ README.md — pending: add link to constitution once project README is
    populated.

Follow-up TODOs: none
-->

# GramartEnglish Constitution

## Core Principles

### I. Test-First (NON-NEGOTIABLE)

TDD is mandatory for all production code. Tests MUST be written first, reviewed,
observed to fail, and only then made to pass. The Red-Green-Refactor cycle
applies to backend services (Node.js), the macOS client (Xcode/Swift), and the
RAG/Ollama integration layer. No feature merges without accompanying tests at
the appropriate level (unit, contract, integration).

**Rationale**: Learning-app correctness directly affects student outcomes;
regressions in vocabulary scoring, grammar checks, or LLM-grounded answers
silently degrade the product. Tests are the only durable specification.

### II. Library-First Architecture

Every feature begins as a self-contained, independently testable library or
Swift package. Cross-cutting concerns (RAG retrieval, prompt assembly, lesson
scoring, persistence) MUST live behind explicit module boundaries with stable
public interfaces. No feature may reach into another's internals.

**Rationale**: A clean library boundary lets us swap Ollama for another LLM,
move RAG storage, or extract a shared package for an iOS port later without
rewriting the app.

### III. Simplicity & YAGNI

Start with the simplest design that satisfies the spec. Do not add
configuration, abstraction layers, or "extensibility hooks" without a concrete
present-day requirement. Three similar lines beat a premature abstraction.
Any added complexity MUST be justified in `Complexity Tracking` of the plan.

**Rationale**: The team is small; complexity compounds. Educational features
evolve through iteration with real learners, not speculative architecture.

### IV. Observability

All backend endpoints and RAG pipeline stages MUST emit structured logs (JSON)
with a correlation ID that propagates from the macOS client through the Node.js
API to the Ollama call and back. Errors MUST include enough context to
reproduce the request offline. The macOS client MUST log to a local rotating
file and surface non-PII diagnostics on demand.

**Rationale**: When an LLM answer is wrong, we need to reconstruct exactly
which retrieved chunks, prompt, and model version produced it. Without
structured traces, RAG bugs are unfixable.

### V. Versioning & Breaking Changes

The project follows Semantic Versioning (`MAJOR.MINOR.PATCH`) across the
backend API, the macOS app, and any shared schema. Breaking API or storage
changes MUST bump MAJOR, ship a migration plan, and remain backward-compatible
for at least one MINOR release where feasible. RAG index schema versions MUST
be embedded in stored vectors so old indexes can be detected and rebuilt.

**Rationale**: A desktop client cannot be force-upgraded; the backend must
tolerate older clients in the field.

### VI. Security & Privacy

Student data (progress, recordings, free-text answers) is treated as sensitive.
Secrets MUST NOT be committed; the macOS app MUST use Keychain for credentials.
LLM prompts MUST NOT include data from other users. All network traffic MUST
use TLS. RAG documents and embeddings MUST be stored with access controls
matching the originating user's tenant. Privacy-relevant changes require an
explicit checklist item in the plan.

**Rationale**: Learners include minors; trust loss from a single leak is
unrecoverable.

### VII. Accessibility

The macOS app MUST support VoiceOver, full keyboard navigation, Dynamic Type,
and respect the system Reduce Motion / Increase Contrast settings. Color MUST
NOT be the sole carrier of meaning. New UI surfaces MUST pass an accessibility
audit checklist before merge.

**Rationale**: A language-learning app is read aloud, navigated by keyboard,
and used across vision abilities. Accessibility is a core competency, not a
late-stage polish.

### VIII. Performance Budgets

Each user-visible interaction has a budget that MUST be honored on the lowest
supported Mac:
- Cold app launch: ≤ 2.0 s
- Lesson screen transition: ≤ 150 ms
- RAG-grounded LLM response (first token): ≤ 1.5 s on local Ollama
- Backend API p95 latency: ≤ 200 ms (excluding LLM call)

Regressions against any budget MUST block merge until resolved or explicitly
waived with a tracked follow-up.

**Rationale**: Latency in a learning loop kills engagement; budgets keep
performance a first-class concern rather than an afterthought.

## Technology & Platform Constraints

The product is delivered as a **native macOS application** built with **Xcode**
(Swift / SwiftUI preferred for new UI; AppKit permitted where SwiftUI is
insufficient). The backend is a **Node.js** service exposing a versioned HTTP
API. The retrieval-augmented generation pipeline uses **Ollama** as the local
LLM runtime, with a vector index colocated with the backend.

Mandatory constraints:

- macOS client: minimum supported macOS version MUST be declared in the plan
  and tested in CI on the oldest supported version.
- Backend: Node.js LTS only; no unreleased Node versions in production.
- LLM: All prompts MUST be assembled by the RAG layer; no free-form prompt
  construction in UI code.
- No third-party LLM cloud provider may receive user data unless explicitly
  approved by an amendment to this constitution.
- All schema changes (API, vector index, local store) MUST ship with a
  migration and a rollback path.

## Development Workflow & Quality Gates

1. Every change starts from a feature spec under `specs/<feature>/spec.md`,
   produced via `/speckit-specify` and clarified via `/speckit-clarify` when
   ambiguous.
2. `/speckit-plan` MUST run the Constitution Check gate before Phase 0 and
   again after Phase 1 design. Violations require entries in
   `Complexity Tracking` with a rejected simpler alternative.
3. `/speckit-tasks` outputs a dependency-ordered task list; tests precede
   implementation tasks for each unit.
4. PRs MUST include:
   - Passing unit + contract + integration tests on changed surfaces.
   - Updated structured logs and trace IDs for any new endpoint or pipeline
     stage.
   - Accessibility audit notes for any UI change.
   - Performance impact statement when touching latency-critical paths.
5. Two-eyes review is required; the reviewer explicitly confirms constitution
   compliance.
6. Releases bump the appropriate SemVer component and include a changelog
   entry referencing the affected principles when relevant.

## Governance

This constitution supersedes any conflicting practice, README guidance, or
informal convention. Amendments require:

- A pull request modifying `.specify/memory/constitution.md` with a Sync Impact
  Report comment block at the top.
- A version bump per the rules in Principle V (MAJOR for incompatible
  governance changes, MINOR for added/expanded principles, PATCH for
  clarifications).
- Reviewer confirmation that all dependent templates
  (`.specify/templates/plan-template.md`, `spec-template.md`,
  `tasks-template.md`) remain consistent.
- A migration note when an amendment invalidates in-flight specs or plans.

All PR reviews MUST verify constitution compliance. Complexity that violates a
principle MUST be either rejected or recorded in `Complexity Tracking` with an
explicit justification. Runtime development guidance lives in `CLAUDE.md` and
per-feature plans; both defer to this constitution on conflict.

**Version**: 1.0.0 | **Ratified**: 2026-05-12 | **Last Amended**: 2026-05-12
