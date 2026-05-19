# Contracts: Vocabulary Lesson MVP

This directory holds the **wire contracts** between the macOS client and the embedded Node.js backend. The contracts are the single source of truth for:

- **Backend route schemas** (validated at runtime via `zod` derived from these definitions).
- **`BackendClient` Swift package** typed methods (generated/maintained from the OpenAPI doc).
- **`tests/contract/`** suites on the backend (HTTP-level tests using `supertest`).

## Files

- [`openapi.yaml`](./openapi.yaml) — OpenAPI 3.1 description of every HTTP endpoint, plus shared schemas.

## Endpoint summary

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/health` | Liveness + version + Ollama availability |
| `GET` | `/v1/levels` | List of CEFR levels and labels |
| `POST` | `/v1/placement/start` | Start placement test, returns questions |
| `POST` | `/v1/placement/submit` | Submit placement answers → estimated level |
| `POST` | `/v1/lessons` | Start a 10-question lesson at a level |
| `POST` | `/v1/lessons/{id}/answers` | Submit one answer |
| `POST` | `/v1/lessons/{id}/complete` | End lesson → score + missed words |
| `GET` | `/v1/words/{word}/examples` | RAG+LLM example sentences |
| `GET` | `/v1/words/{word}/definition` | RAG+LLM contextual definition |

## Cross-cutting rules

- Every request **MUST** include `x-correlation-id: <uuid-v4>`. The backend logs it on every line and tags every `AIGeneration` row with it.
- All routes are versioned under `/v1`. Any breaking change requires a `/v2/*` path and SemVer MAJOR bump (Principle V).
- LLM-touching endpoints (`/words/*/examples`, `/words/*/definition`) MUST return HTTP `200` with `fallback: true` and `generatedBy: "fallback_canonical"` when Ollama is unavailable, **or** `503` with the same fallback body. The client treats both as "show fallback" (FR-011). Returning a non-fallback error is forbidden.
- No endpoint accepts or returns personal data (FR-018). The "user" is an implicit singleton.
