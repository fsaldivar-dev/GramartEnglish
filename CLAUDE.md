<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:

- Active feature: `003-writing-modes`
- Plan: [specs/003-writing-modes/plan.md](specs/003-writing-modes/plan.md)
- Spec: [specs/003-writing-modes/spec.md](specs/003-writing-modes/spec.md)
- Data model delta: [specs/003-writing-modes/data-model.md](specs/003-writing-modes/data-model.md)
- Contracts delta: [specs/003-writing-modes/contracts/openapi-delta.yaml](specs/003-writing-modes/contracts/openapi-delta.yaml)
- Research: [specs/003-writing-modes/research.md](specs/003-writing-modes/research.md)
- F002 (shipped, still authoritative for listening + per-mode mastery): [specs/002-listening-modes/](specs/002-listening-modes/)
- MVP foundation (still authoritative for unchanged areas): [specs/001-vocabulary-lesson-mvp/](specs/001-vocabulary-lesson-mvp/)
- Constitution: [.specify/memory/constitution.md](.specify/memory/constitution.md)

**Mastery is per-(word, mode)** as of Feature 002. A word can be mastered in `read_pick_meaning` and still be "to-review" in `listen_pick_word` or `write_type_word`. F003 adds three write modes (Spanish prompt → English answer) without any schema migration; `schemaVersion` stays at 3.
<!-- SPECKIT END -->
