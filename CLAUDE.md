<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:

- Active feature: `007-persistence-prosody-tokens` (v1.8.0 shipped — lesson-state persistence, slow-rate TTS, design tokens, distractor hygiene)
- Plan: [specs/007-persistence-prosody-tokens/plan.md](specs/007-persistence-prosody-tokens/plan.md)
- Spec: [specs/007-persistence-prosody-tokens/spec.md](specs/007-persistence-prosody-tokens/spec.md)
- Data model delta: [specs/007-persistence-prosody-tokens/data-model.md](specs/007-persistence-prosody-tokens/data-model.md)
- Research: [specs/007-persistence-prosody-tokens/research.md](specs/007-persistence-prosody-tokens/research.md)
- Evaluator personas: [specs/team-personas.md](specs/team-personas.md)
- F006 (shipped, verb intro card): [specs/006-verb-intro-card/](specs/006-verb-intro-card/)
- F004 (shipped, conjugate_pick_form): [specs/004-verb-conjugation/](specs/004-verb-conjugation/)
- F005 (shipped, adaptive placement): [specs/005-adaptive-placement/](specs/005-adaptive-placement/)
- F003 (shipped, write modes): [specs/003-writing-modes/](specs/003-writing-modes/)
- F002 (shipped, listening + per-mode mastery): [specs/002-listening-modes/](specs/002-listening-modes/)
- MVP foundation (still authoritative for unchanged areas): [specs/001-vocabulary-lesson-mvp/](specs/001-vocabulary-lesson-mvp/)
- Constitution: [.specify/memory/constitution.md](.specify/memory/constitution.md)

**Mastery is per-(word, mode)** as of Feature 002. A word can be mastered in `read_pick_meaning` and still be "to-review" in `listen_pick_word`, `write_type_word`, or `conjugate_pick_form`. F003 added write modes (Spanish prompt → English answer); F005 made placement adaptive; F004 v1.6.0 added `conjugate_pick_form` (Spanish verb infinitive → English past form, simple_past only, A2+B1, 60 verbs). F006 v1.7.0 added a per-Mac, per-verb "Conoce el verbo" pre-conjugation micro-card. F007 v1.8.0 added: lesson-state persistence to `~/Library/Application Support/GramartEnglish/lesson-state.json` (survives Cmd+Q), `SpeechRate.normal/.slow` prosody buttons, `DesignTokens.swift` (Spacing/Radius/Tint/Semantic), and a distractor-hygiene fix that removes `goed`/`runed` from `conjugate_pick_form` options and surfaces them as an `AnswerResult.feedbackHint` instead. `schemaVersion` stays at 3.
<!-- SPECKIT END -->
