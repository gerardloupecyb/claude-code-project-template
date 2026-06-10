---
name: session-gate
description: "Validation mécanique de l'état de session (MEMORY.md). This skill should be used when validating session state at boundaries. Triggers on: session gate, valider la session, vérifier mémoire, état de la session. Also invoked explicitly with /session-gate."
---

# Session Gate — Validation mécanique de MEMORY.md

Verify that memory/MEMORY.md follows the template rules mechanically.
Read-only, advisory, stateless. Never modify files. Never block the session.

## References

Load reference files based on mode — do not load all three upfront.

| File | Load when |
|------|-----------|
| `references/checks-common.md` | **Always** — checks 1, 4, 5, 8, 11, 15 (run in every mode) |
| `references/checks-start-only.md` | START or BOTH mode — checks 2, 3, 12, 13, 14 |
| `references/checks-end-only.md` | END or BOTH mode — checks 6, 7, 9, 10, 16, 17, 18, 19, 20, 21, 22 |

---

## Invocation

| Command | Mode | Checks |
|---------|------|--------|
| `/session-gate start` | START | 1, 2, 3, 4, 5, 8, 11, 12, 13, 14, 15 |
| `/session-gate end` | END | 1, 4, 5, 6, 7, 8, 9, 10, 11, 15, 16, 17, 18, 19, 20, 21, 22 |
| `/session-gate` (no arg) | BOTH | All 22 |

---

## Pre-check: merge conflicts

Before running any check, scan memory/MEMORY.md for lines starting with
`<<<<<<<`, `=======`, or `>>>>>>>`. If found, report:

```
Session Gate — BLOCKED

  MEMORY.md contains unresolved merge conflicts. Resolve them before continuing.
```

Skip all remaining checks.

---

## Output format

```
Session Gate — {MODE}

  [ok]  MEMORY.md exists and is non-empty
  [--]  "Dernière session" 2026-03-10 (1 day ago)
  [!!]  "Déviations d'exécution" has 2 entries — clear them
  [ok]  "Ce qui a été fait": 3/5
  [ok]  "Prochaine étape" present
  [ok]  LESSONS.md exists and is non-empty
  [ok]  COT plan block present in 2026-03-16-001-...-plan.md
  [--]  LESSONS.md has only 2 entries (< 3) — consider running /lesson

  1 issue found. Fix before continuing.
```

Legend: `[ok]` = pass, `[!!]` = action required, `[--]` = informational.

If any `[!!]` checks exist, report count and recommend fixing.
If no `[!!]` checks, end with: "All clear."

---

## What this skill does NOT do

- Modify any file (read-only, like pre-flight)
- Block the session (advisory only — user decides)
- Judge content quality ("is this next step good?")
- Read STATE.md (no coupling with GSD)
- Require state between invocations (stateless)
