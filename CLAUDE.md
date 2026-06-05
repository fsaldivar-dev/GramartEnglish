<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:

- Active feature: `006-verb-intro-card` (v1.7.0 shipped — "Conoce el verbo" pre-conjugation micro-card, F006 US1)
- Plan: [specs/006-verb-intro-card/plan.md](specs/006-verb-intro-card/plan.md)
- Spec: [specs/006-verb-intro-card/spec.md](specs/006-verb-intro-card/spec.md)
- Data model delta: [specs/006-verb-intro-card/data-model.md](specs/006-verb-intro-card/data-model.md)
- Research: [specs/006-verb-intro-card/research.md](specs/006-verb-intro-card/research.md)
- F004 (shipped, conjugate_pick_form): [specs/004-verb-conjugation/](specs/004-verb-conjugation/)
- F005 (shipped, adaptive placement): [specs/005-adaptive-placement/](specs/005-adaptive-placement/)
- F003 (shipped, write modes): [specs/003-writing-modes/](specs/003-writing-modes/)
- F002 (shipped, listening + per-mode mastery): [specs/002-listening-modes/](specs/002-listening-modes/)
- MVP foundation (still authoritative for unchanged areas): [specs/001-vocabulary-lesson-mvp/](specs/001-vocabulary-lesson-mvp/)
- Constitution: [.specify/memory/constitution.md](.specify/memory/constitution.md)

**Mastery is per-(word, mode)** as of Feature 002. A word can be mastered in `read_pick_meaning` and still be "to-review" in `listen_pick_word`, `write_type_word`, or `conjugate_pick_form`. F003 added write modes (Spanish prompt → English answer); F005 made placement adaptive; F004 v1.6.0 added `conjugate_pick_form` (Spanish verb infinitive → English past form, simple_past only, A2+B1, 60 verbs). F006 v1.7.0 added a per-Mac, per-verb "Conoce el verbo" pre-conjugation micro-card with bilingual example; persistence via `UserDefaults` key `gramart.verbIntro.seen`. `schemaVersion` stays at 3.
<!-- SPECKIT END -->
