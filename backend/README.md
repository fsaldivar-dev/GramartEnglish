# GramartEnglish backend

Embedded local Node.js service consumed by the macOS app via `127.0.0.1` on an
ephemeral port. Never exposed to the network. See
[../specs/001-vocabulary-lesson-mvp/plan.md](../specs/001-vocabulary-lesson-mvp/plan.md)
for the architecture.

## Toolchain

- **Node.js 20 LTS** (mandatory; `engines.node` enforces `^20`).
- **pnpm 9** as the package manager (not npm, not yarn). A `preinstall` script
  refuses installs by anything else.

Why pnpm:

1. Strict module isolation — no phantom imports.
2. `onlyBuiltDependencies` — install-time scripts (`postinstall` etc.) run
   ONLY for the explicitly allowlisted packages (`better-sqlite3`,
   `hnswlib-node`, `esbuild`). Every other dep is install-script-blocked.
3. `minimumReleaseAge: 1440` — packages must be at least 24 hours old before
   pnpm will install them. Mitigates fast-moving supply-chain attacks where
   a compromised version is yanked within hours.
4. Hash verification + frozen lockfile in CI.

## Install

```bash
# 1. Ensure Node 20 LTS is active
node -v   # → v20.x.x

# 2. Install pnpm (one-time)
brew install pnpm                # OR: corepack enable && corepack prepare pnpm@9 --activate

# 3. Install deps
cd backend
pnpm install
```

The first install of `better-sqlite3` and `hnswlib-node` compiles native
bindings. Allow ~30 s.

## Scripts

| Command | Purpose |
|---------|---------|
| `pnpm run dev` | tsx watch on `src/server.ts` |
| `pnpm run build` | `tsc` + esbuild bundle |
| `pnpm test` | Vitest unit + integration + contract tests |
| `pnpm run lint` | ESLint over `src/` and `tests/` |
| `pnpm run audit` | `pnpm audit --prod` (production deps only) |
| `pnpm run ingest` | One-shot CEFR ingestion into SQLite + HNSW index |

## Supply-chain hygiene

- Add a dependency: `pnpm add <pkg>` — it lands in `dependencies`. Review the
  diff in `pnpm-lock.yaml` before committing.
- Add a dev dependency: `pnpm add -D <pkg>`.
- If the new dep needs `postinstall` (native module), add it to
  `pnpm.onlyBuiltDependencies` in `package.json` and explain why in the PR.
- Run `pnpm audit --prod --audit-level=high` before tagging a release.
- Lockfile is the source of truth — CI uses `--frozen-lockfile`.
