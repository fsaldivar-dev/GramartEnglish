# Phase 0 Research: Vocabulary Lesson MVP

**Date**: 2026-05-12
**Branch**: `001-vocabulary-lesson-mvp`

This document resolves the open technical questions from the plan's Technical Context. Each item lists the **Decision**, **Rationale**, and the **Alternatives considered** with why they were rejected.

---

## 1. Ollama model choice for the MVP

**Decision**: Use **`llama3.1:8b-instruct-q4_K_M`** as the default generation model and **`nomic-embed-text`** as the embedding model. Both run locally via Ollama.

**Rationale**:

- `llama3.1:8b` at Q4_K_M quantization fits in ~5 GB VRAM/UMA, runs at acceptable token rates (~50 tok/s on M1) and consistently produces correct example sentences for English vocabulary tasks.
- `nomic-embed-text` is small (~270 MB), fast on Apple Silicon, and high-quality for English-only corpus retrieval. It is what Ollama recommends as the default text embedder.
- Both ship via `ollama pull`, so the app can ensure availability on first run.

**Alternatives considered**:

- `gemma2:9b-instruct-q4_K_M` — comparable quality but ~10 % slower first-token latency on M1; rejected as it would put SC-004 (1.5 s) at risk.
- `phi3:mini` — fast but produced more hallucinated/awkward example sentences in informal evaluation; rejected for didactic-quality reasons.
- `bge-small-en` — strong embeddings, but no first-party Ollama image; using `ollama` for both models keeps the dependency surface small.

---

## 2. Node.js HTTP framework

**Decision**: **Fastify 4.x**.

**Rationale**:

- Smallest startup overhead among mainstream frameworks (~50 ms on M1), important because the backend launches with every app open (SC-003 ≤ 2 s cold start).
- Built-in JSON schema validation pairs naturally with the OpenAPI contracts (`contracts/openapi.yaml`).
- Native plugin model maps cleanly onto our `routes/`, `observability/`, `lessons/` modules (Principle II).

**Alternatives considered**:

- Express — ubiquitous but heavier per-request and no first-class schema validation; rejected.
- Hono — extremely lean, but its ecosystem on Node.js (vs Bun/edge runtimes) is thinner and SQLite + native modules require Node anyway; rejected.

---

## 3. Local vector index

**Decision**: **`hnswlib-node`** persisting to a single `rag.index` file alongside SQLite.

**Rationale**:

- No external process to supervise (rules out qdrant/chroma servers, keeps Principle III satisfied).
- HNSW gives sub-millisecond nearest-neighbor lookup over ~10k vectors (our corpus is far smaller).
- Mature native binding, MIT licensed, builds cleanly for arm64.

**Alternatives considered**:

- `sqlite-vss` — would keep everything in SQLite, attractive operationally; rejected because the extension's arm64 macOS build story is fragile and we want the index pluggable.
- Qdrant / Chroma server — overkill for a single-user local app and adds a second supervised process.

---

## 4. RAG pipeline shape

**Decision**: Two-stage retrieval grounded in the curated CEFR corpus:

1. **Lexical filter**: lookup the queried word's row in SQLite to get its canonical definition, POS, level, and any canonical example sentences.
2. **Semantic retrieval**: HNSW nearest-neighbor over chunked example/usage snippets to pull 3–5 supporting passages.

The LLM prompt receives: canonical entry + retrieved passages + target CEFR level + task ("examples" or "contextual definition"). The system prompt forbids invention beyond the provided context.

**Rationale**:

- The canonical entry guarantees the LLM has the correct meaning to anchor on (Principle "no hallucinations" / spec FR-010).
- Semantic retrieval over example snippets handles the contextual-definition case for polysemous words.
- Two-stage keeps prompts short (helps SC-004).

**Alternatives considered**:

- Pure semantic retrieval — risks pulling unrelated examples for polysemous words.
- Long-context prompts with the whole word entry — wasteful tokens, slower first-token latency.

---

## 5. macOS ↔ Backend handshake

**Decision**: The Swift app launches the Node binary as a `Foundation.Process` child, listening on `127.0.0.1:0` (OS-assigned ephemeral port). The backend prints a single JSON line `{ "port": <n>, "pid": <pid>, "version": "x.y.z" }` to stdout when ready; the app reads that line and connects. The child is killed via `terminate()` on app shutdown and watched for unexpected exit (auto-relaunch up to 2 times before showing an error).

**Rationale**:

- Random ephemeral port avoids collisions and never exposes a predictable port.
- Stdout handshake is portable, requires no inter-process discovery files, and is observable for logging.
- Binding to `127.0.0.1` keeps the API off the network entirely (Principle VI).

**Alternatives considered**:

- Unix domain socket — slightly more secure but requires custom URLSession protocol handling on the Swift side, more complexity for negligible additional safety.
- Fixed port (e.g., 47731) — simplest, but clashes when the user runs two builds simultaneously and is easier to scan.

---

## 6. Embedding & shipping the Node.js runtime

**Decision**: Ship a single architecture-specific (`arm64`) Node 20 LTS binary plus the compiled backend (`dist/`) and `node_modules/` inside the macOS `.app` bundle's `Contents/Resources/backend/`. Use `npm ci --omit=dev` + esbuild to bundle the entrypoint and tree-shake unused code. Native modules (`better-sqlite3`, `hnswlib-node`) are compiled for `arm64` and bundled in `node_modules/`.

**Rationale**:

- Single architecture (arm64) keeps the bundle small (target < 80 MB compressed) and matches the platform decision (Apple Silicon only).
- Bundling avoids requiring the user to have Node installed (zero-install constraint of "embedded backend" clarification).

**Alternatives considered**:

- `pkg`/`nexe` single-binary — historically incompatible with native modules built for the current Node version; rejected.
- Bun — would simplify the binary story but adds risk around `better-sqlite3` / `hnswlib-node` compatibility and Node-LTS-only constitution.

---

## 7. Placement test scoring algorithm

**Decision**: Show ~12 questions (2 per CEFR level) drawn from the curated corpus. Score each level by the percent correct of its 2 questions; estimated level = the highest level where the user scored ≥ 50 %, then bumped one step down if the user got the level above it 100 % wrong. Default to **A2** if all signals are noisy.

**Rationale**:

- Simple, transparent, and explainable to the user ("you got 4/6 of B1 right → starting at B1").
- 12 questions stays under the user's tolerance for onboarding friction (~90 s).
- No ML / IRT model is needed for MVP.

**Alternatives considered**:

- Adaptive testing (IRT) — better accuracy but significant complexity for a v1.
- 6-question test (1 per level) — too noisy.

---

## 8. CEFR corpus sourcing & licensing

**Decision**: Build the corpus from public-domain / openly licensed sources, primarily the **CEFR-J Wordlist** (Creative Commons BY-SA 4.0) and **English Vocabulary Profile** for level signal. Canonical definitions are author-written (paraphrased, not copied) by a project contributor; example sentences are either author-written or sourced from public-domain corpora (e.g., Tatoeba CC-BY).

**Rationale**:

- CEFR-J + EVP cover all six levels with explicit CEFR mappings.
- All licenses permit redistribution inside a non-commercial product; the spec explicitly notes "curated manually for MVP".

**Alternatives considered**:

- Oxford 3000/5000 — well-known but copyrighted; rejected.
- Auto-generate definitions with the LLM at build time — risk of subtle errors; rejected for the MVP corpus (LLM is for runtime augmentation, not the source of truth).

---

## 9. Structured logging & correlation IDs

**Decision**: `pino` on the backend with `transport: 'pino-pretty'` only in development. Every HTTP request gets a `x-correlation-id` header generated by the macOS client (UUID v4); the backend adopts it and propagates to every log line and every Ollama call. Logs go to stdout (captured by the parent app's logger) and to a rotating file under `~/Library/Logs/GramartEnglish/backend-*.log` (≤ 10 MB × 5 files).

**Rationale**: Satisfies Principle IV: a single ID joins UI events, backend logs, and AI generation records. Privacy-friendly: logs never contain user-identifying data because there is none (FR-018).

**Alternatives considered**:

- OpenTelemetry — too much surface area for an offline single-user app.
- Plain `console.log` — unstructured, harder to grep; rejected.

---

## 10. macOS app packaging & code signing

**Decision**: Use Xcode's archive + notarization workflow. App is hardened-runtime, sandboxed with `com.apple.security.app-sandbox` and **without** `com.apple.security.network.client/server` entitlements (the backend talks only on `127.0.0.1`, which the sandbox permits internally when the child process is itself sandboxed via inheritance).

**Rationale**:

- Hardened runtime + notarization is required for distribution outside the Mac App Store.
- Avoids any network entitlement, which is consistent with "no outbound HTTP".

**Alternatives considered**:

- Distribute outside notarization (Gatekeeper bypass instructions) — unacceptable user friction; rejected.

---

## 11. Test strategy for non-determinism (LLM)

**Decision**: Backend tests stub Ollama with a recorded-response fake (`src/llm/__fakes__/recorded.ts`). A separate, optional "live" suite runs against a real Ollama instance and is excluded from the default `npm test`. Determinism for example-quality tests is achieved by asserting on **invariants** (returned text contains the queried word or a valid morphological form; cited RAG source IDs exist; response shape conforms to the OpenAPI contract) rather than exact strings.

**Rationale**: Honors Principle I (Test-First) without making the suite flaky. Aligns with FR-008 acceptance: "frases deben contener la palabra exacta o una flexión válida".

**Alternatives considered**:

- No tests for LLM-touching code — violates Principle I.
- Asserting exact LLM outputs — flaky.

---

## Summary: All NEEDS CLARIFICATION resolved

| Topic | Status |
|-------|--------|
| Ollama model choice | ✅ Resolved (`llama3.1:8b-instruct-q4_K_M` + `nomic-embed-text`) |
| HTTP framework | ✅ Resolved (Fastify) |
| Vector index | ✅ Resolved (hnswlib-node, file-backed) |
| RAG pipeline shape | ✅ Resolved (lexical + semantic, grounded) |
| Process handshake | ✅ Resolved (stdout JSON + 127.0.0.1:0) |
| Runtime bundling | ✅ Resolved (arm64 Node 20 + native modules in bundle) |
| Placement scoring | ✅ Resolved (per-level threshold, default A2) |
| Corpus sourcing | ✅ Resolved (CEFR-J / EVP / Tatoeba) |
| Logging | ✅ Resolved (pino + correlation-id header) |
| Packaging | ✅ Resolved (hardened runtime, no network entitlement) |
| LLM test strategy | ✅ Resolved (stubbed by default, invariants over exact strings) |
