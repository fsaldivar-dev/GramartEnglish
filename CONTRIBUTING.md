# Contributing to GramartEnglish

Thanks for your interest. GramartEnglish is built **spec-first** and reviews enforce the [project constitution](.specify/memory/constitution.md). Please read this guide before opening a PR.

## Workflow at a glance

```
constitution        (rare; only when project rules change)
  ↓
specify  →  clarify  →  plan  →  tasks  →  [analyze]  →  implement
   (per feature, in its own git branch and specs/ folder)
```

We use [spec-kit](https://github.com/github/spec-kit) commands. Each generates a checked-in artifact under `specs/<NNN>-<feature-name>/`.

## Adding a feature

1. **Branch**: `/speckit-git-feature` creates `<NNN>-<short-name>` and a `specs/<NNN>-…/` folder.
2. **Specify**: `/speckit-specify` produces `spec.md` from a plain-language description. Focus on *what* and *why*, not *how*.
3. **Clarify** *(optional)*: `/speckit-clarify` resolves ambiguities by asking up to 5 questions.
4. **Plan**: `/speckit-plan` produces `plan.md`, `research.md`, `data-model.md`, `contracts/`. The plan **must** include a Constitution Check section that passes or documents justified exceptions in *Complexity Tracking*.
5. **Tasks**: `/speckit-tasks` produces `tasks.md` with dependency-ordered, file-pathed tasks grouped by user story.
6. **Analyze** *(optional)*: `/speckit-analyze` cross-checks artifacts for inconsistencies.
7. **Implement**: `/speckit-implement` executes the tasks in phases. Tests precede implementation (Principle I).

## Constitution gates

Every PR must pass these gates before merge:

| Gate | What reviewers check |
|------|----------------------|
| **Test-First** | New code has tests authored before or alongside it; CI is green. |
| **Library-First** | Cross-cutting logic lives in `app/Packages/*` or `backend/src/<module>/`, not glue inside features. |
| **Simplicity** | No abstraction without a *current* requirement. Three similar lines beats a premature helper. |
| **Observability** | New routes / pipelines emit structured logs with `correlationId`. AI generations write `AIGeneration` rows. |
| **Versioning** | Breaking schema/API changes bump SemVer and ship a migration. |
| **Privacy** | No telemetry, no outbound HTTP, no PII fields. |
| **Accessibility** | UI changes include VoiceOver labels, keyboard shortcuts, Dynamic Type handling. |
| **Performance** | Touching latency-critical paths includes a perf statement. |

## Bilingual artifact convention

Existing specs were authored bilingually (Spanish for product/spec narrative, English for technical docs and code). Future specs may use either language, but:

- Code identifiers, log keys, and field names are **English**.
- User-facing strings live in localized resources where applicable.
- Within a single artifact, pick one language and stay consistent.

## Local toolchain

See [README.md](README.md#tooling) for required versions. Quick check:

```bash
node -v   # v20.x
pnpm -v   # 9.x
xcodebuild -version
ollama list
```

If `pnpm install` fails with native-module compilation errors, you are very likely on a non-LTS Node release. Switch to Node 20.

## Tests

```bash
# Backend
cd backend && pnpm test

# Swift packages
cd app/Packages/LessonKit && swift test
cd app/Packages/BackendClient && swift test
cd app/GramartEnglish && swift test
```

CI runs all of the above plus `pnpm audit --prod --audit-level=high`.

## Supply-chain hygiene

- Add a dep: `pnpm add <pkg>`. Review `pnpm-lock.yaml` carefully.
- Native modules with `postinstall` must be listed in `package.json -> pnpm.onlyBuiltDependencies` (currently `better-sqlite3`, `hnswlib-node`, `esbuild`).
- New deps are not installed for 24 h after release (`pnpm.minimumReleaseAge: 1440`).

## Style

- TypeScript: strict mode, ESLint, Prettier; no `any` without justification.
- Swift: SwiftUI preferred; SwiftLint config at `app/.swiftlint.yml`.
- Tests: invariants over exact LLM outputs (LLM outputs are non-deterministic).
- Default to no comments. Only explain *why* if non-obvious; never narrate *what*.

## Commit messages

Short imperative subject (under ~70 chars). Body explains *why*. Reference the spec when relevant:

```
feat(US1): start lesson + 50/30/20 word selector

Backs spec FR-013a. Sources mix from new (50%), failed (30%),
refresh (20%); falls back to "new" pool when other categories
are empty.
```

## Releases

Single SemVer in `version.json` covers app + backend. Bump per Principle V:

- **PATCH** — clarifications, bug fixes, no API changes
- **MINOR** — new endpoints/features, additive only
- **MAJOR** — breaking API or storage changes (ship migration)
