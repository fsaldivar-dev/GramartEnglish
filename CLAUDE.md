<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:

- Active feature: `005-adaptive-placement` (shipped); next: pending PO+TL deliberation
- Plan: [specs/005-adaptive-placement/plan.md](specs/005-adaptive-placement/plan.md)
- Spec: [specs/005-adaptive-placement/spec.md](specs/005-adaptive-placement/spec.md)
- Data model delta: [specs/005-adaptive-placement/data-model.md](specs/005-adaptive-placement/data-model.md)
- Research: [specs/005-adaptive-placement/research.md](specs/005-adaptive-placement/research.md)
- F003 (shipped, write modes): [specs/003-writing-modes/](specs/003-writing-modes/)
- F002 (shipped, listening + per-mode mastery): [specs/002-listening-modes/](specs/002-listening-modes/)
- MVP foundation (still authoritative for unchanged areas): [specs/001-vocabulary-lesson-mvp/](specs/001-vocabulary-lesson-mvp/)
- Constitution: [.specify/memory/constitution.md](.specify/memory/constitution.md)

**Mastery is per-(word, mode)** as of Feature 002. A word can be mastered in `read_pick_meaning` and still be "to-review" in `listen_pick_word` or `write_type_word`. F003 added write modes (Spanish prompt → English answer); F005 made placement adaptive. `schemaVersion` stays at 3.
<!-- SPECKIT END -->
