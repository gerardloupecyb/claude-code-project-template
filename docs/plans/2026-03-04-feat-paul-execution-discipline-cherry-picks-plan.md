---
title: "feat: Add PAUL execution discipline to project template"
type: feat
date: 2026-03-04
brainstorm: docs/brainstorms/2026-03-04-paul-cherry-picks-brainstorm.md
deepened: 2026-03-04
---

# feat: Add PAUL Execution Discipline to Project Template

## Enhancement Summary

**Deepened on:** 2026-03-04
**Sections enhanced:** All
**Agents used:** architecture-strategist, code-simplicity-reviewer, best-practices-researcher, context-manager-skill, spec-flow-analyzer

### Key Improvements from Deepening

1. **RULE_5 target section changed** — "Décisions actives" was the wrong semantic layer for deviations. New dedicated "Déviations d'exécution" section in MEMORY.md template (context-manager finding)
2. **RULE_5 trigger narrowed** — "new file modified" was too broad and would generate noise. Replaced with boundary-violation focus (architecture finding)
3. **RULE_4 recovery path added** — If SUMMARY.md exists but lacks reconciliation, orchestrator must add it (architecture finding)
4. **BDD criteria made unconditional** — Dropped the 3+ task threshold. Every plan gets at least one AC. The overhead of one Given/When/Then line is negligible; the overhead of remembering the threshold is not (simplicity finding)
5. **Boundaries kept but surfaced** — Added "read Boundaries before first wave" to workflow block (architecture finding). Not a CARL rule, but an explicit workflow instruction
6. **Cross-layer reference fixed** — Règle #8 no longer references "CARL RULE_5" by name. Uses behavior description instead (architecture finding)
7. **New file: MEMORY.md template update** — Added bounded "Déviations d'exécution" section (max 5 entries, cleared each session)

---

## Overview

Integrate 4 concepts from the [PAUL framework](https://github.com/christopherKahler/paul) into project-template-v2 to close the gap between planning and execution reconciliation. Currently, the template's flywheel captures **what we learned** but nothing enforces reconciling **what we planned** vs **what we did**.

## Problem Statement

Plans can be executed via `/gsd:execute-phase`, things can drift from the plan, and nobody notices. GSD creates SUMMARY.md files but no CARL rule enforces that they compare planned vs actual. Plans lack objective acceptance criteria for verification. There's no mechanism to protect critical files during execution or to log when execution diverges from the plan.

## Proposed Solution

Add execution discipline through 2 new CARL rules in the domain template, 3 updates to CLAUDE.md.template, and 1 update to MEMORY.md.template. No new commands, directories, or skills — stays within existing architecture.

## Acceptance Criteria

- AC-1: Given a new project scaffolded with `init-project.sh`, When I check `.carl/{domain}`, Then RULE_4 (LOOP CLOSURE) and RULE_5 (DEVIATION LOGGING) are present and active
- AC-2: Given a project with the updated CLAUDE.md, When I read the workflow sections, Then closure is shown as a mandatory step after `/gsd:execute-phase`
- AC-3: Given the updated CLAUDE.md, When I read Règle #8, Then BDD acceptance criteria (Given/When/Then) are documented as required for all plans
- AC-4: Given the updated CLAUDE.md, When I read the plan structure requirements, Then a `## Boundaries` section is documented as required for all plans
- AC-5: Given the updated MEMORY.md template, When I read it, Then a "Déviations d'exécution" section exists with a max-5-entries bounded table

## Technical Approach

### File 1: `.carl/domain.template`

**Current state (lines 17-22):**

```
# --- PROJECT-SPECIFIC RULES (add below) ---

# {{CARL_DOMAIN_UPPER}}_RULE_4=
# {{CARL_DOMAIN_UPPER}}_RULE_5=
# {{CARL_DOMAIN_UPPER}}_RULE_6=
```

**Target state:**

```
# --- EXECUTION DISCIPLINE (PAUL) ---

{{CARL_DOMAIN_UPPER}}_RULE_4=LOOP CLOSURE: After every /gsd:execute-phase, verify that .planning/{phase}-SUMMARY.md exists and includes: planned tasks vs completed tasks, decisions made during execution, and items deferred. If the file exists but lacks a planned-vs-actual comparison, add the reconciliation section before proceeding. This closure is MANDATORY before running /workflows:review.

{{CARL_DOMAIN_UPPER}}_RULE_5=DEVIATION LOGGING: If execution diverges from the plan — task skipped, scope changed, different approach taken, or a file in the plan's Boundaries section touched — log the deviation and reason in MEMORY.md under "Déviations d'exécution" BEFORE proceeding. New implementation files created as part of completing a planned task are NOT deviations. Never silently drift from the plan.

# --- PROJECT-SPECIFIC RULES (add below) ---

# {{CARL_DOMAIN_UPPER}}_RULE_6=
# {{CARL_DOMAIN_UPPER}}_RULE_7=
# {{CARL_DOMAIN_UPPER}}_RULE_8=
```

**Rationale:**

- RULE_4 leverages GSD's existing SUMMARY.md artifact — no new file. Enforces content contract (planned vs actual comparison). Includes recovery path: if SUMMARY.md exists but is content-incomplete, the orchestrator adds the reconciliation section.
- RULE_5 targets a new dedicated "Déviations d'exécution" section in MEMORY.md instead of "Décisions actives" — correct semantic layer. "Décisions actives" is for durable decisions influencing code; deviations are ephemeral process events.
- RULE_5 trigger explicitly excludes "new implementation files created as part of completing a planned task" — prevents noise from normal GSD execution where subagents create files not individually named in the plan.
- Section divider follows existing convention (`# --- FOUNDATIONAL RULES ---`, `# --- PROJECT-SPECIFIC RULES ---`).
- Commented-out slots shift to RULE_6/7/8 so projects still have room for custom rules.

### Research Insights — CARL Rules

**Best Practices (from CARL skill analysis):**

- Rule labels (LOOP CLOSURE:, DEVIATION LOGGING:) follow ALL_CAPS_LABEL: convention
- Rules are one paragraph, no internal line breaks — both rules comply
- Both rules use imperative language ("verify", "log", "never") — correct
- No conflict with RULE_0-3 (context, flywheel consult, flywheel document, credentials)
- RECALL keywords from the manifest will trigger these rules when CARL context matches

**Deviation Trigger Definition (from BDD research + architecture review):**

What IS a deviation:
- Task skipped entirely
- Scope changed (added or removed work)
- Different approach taken than planned
- File in Boundaries section touched
- Planned library or dependency swapped

What is NOT a deviation:
- New implementation files created as part of completing a planned task
- Task reordered but same outcome achieved
- Minor implementation detail differs (variable name, comment style)
- Better approach discovered that satisfies same AC

---

### File 2: `CLAUDE.md.template` — Workflow Blocks

**Change 1: Basic workflow (line 61)**

Add closure arrow after `/gsd:execute-phase`:

```
/gsd:execute-phase       → exécuter avec subagents frais en waves parallèles
  → closure obligatoire  → résumé planifié vs réalisé (CARL RULE_4)
```

**Change 2: Detailed workflow (lines 78-81)**

Insert boundary read + closure step between execute and review:

```
Phase exécution :
  /gsd:execute-phase (waves parallèles, commits atomiques)
    → lire ## Boundaries du PLAN.md avant la première wave
  → closure (OBLIGATOIRE — résumé planifié vs réalisé, décisions, items différés)
  → /workflows:review (15 agents review spécialisés)
  → /gsd:verify-work (UAT goal-backward — vérifie les AC)
```

### Research Insights — Workflow Block

**Architecture review finding:** Adding "lire ## Boundaries du PLAN.md avant la première wave" costs one line and converts the Boundaries section from a passive artifact to an active constraint. Without this explicit read instruction, the Boundaries section would be present in the plan but invisible during execution.

---

### File 3: `CLAUDE.md.template` — New Règle #8

Insert after Règle #7 (line 232) and before the Flywheel section (line 235):

```markdown
### Règle #8 — Structure des plans : critères d'acceptation et frontières

Tout plan créé par `/gsd:plan-phase` ou `/workflows:plan` doit inclure :

#### Critères d'acceptation (BDD)

Format obligatoire Given/When/Then pour tout plan :

AC-1: Given [contexte], When [action], Then [résultat attendu]
AC-2: Given [contexte], When [action], Then [résultat attendu]

Chaque tâche doit référencer quel AC elle satisfait (ex: "→ satisfait AC-1").
Les critères doivent être déclaratifs (comportement attendu), pas impératifs (étapes mécaniques).
Les critères servent de référence pour `/gsd:verify-work` (UAT goal-backward).

Règles pour écrire de bons AC :
- Un seul comportement par AC (ne pas combiner plusieurs vérifications)
- Le "Then" doit être vérifiable par lecture de fichier ou exécution de commande
- Pas de détails d'implémentation dans le "Then" (tester le comportement, pas le code)

#### Frontières — tous les plans

Lister explicitement les fichiers et répertoires qui ne doivent PAS être modifiés :

## Boundaries
- CLAUDE.md (ne pas modifier)
- .carl/ (ne pas modifier sauf si flywheel)
- [autres fichiers protégés selon contexte]

Les frontières protègent contre les modifications accidentelles pendant l'exécution.
Si une tâche nécessite de modifier un fichier listé en frontière,
le signaler comme déviation dans MEMORY.md avant de procéder.
```

### Research Insights — Règle #8

**Simplicity review finding — BDD threshold dropped:**
The original plan required BDD only for plans with 3+ tasks. The simplicity reviewer correctly identified that task count is a poor proxy for "does this plan need acceptance criteria." A 2-task plan touching authentication needs AC more than a 6-task refactoring. The overhead of one Given/When/Then line is negligible; the overhead of remembering and applying a threshold rule is not. Now unconditional — every plan gets at least one AC.

**BDD research finding — Anti-patterns to avoid:**
1. Implementation details in "Then" clause (line numbers, exact strings) → breaks on formatting changes
2. Compound criteria testing multiple behaviors → can't identify which part failed
3. Untestable "Then" clauses ("should be well-structured") → AI executor skips or hallucinates
4. Criteria written after tasks → become tautological instead of defining "done"
5. No criteria at all → biggest anti-pattern, creates invisible drift

**Architecture review finding — Cross-layer reference removed:**
Original text referenced "CARL RULE_5" by name. Rule numbers are physical addresses, not semantic contracts. If a project adds custom rules before RULE_5, the reference becomes stale. Changed to behavioral description: "signaler comme déviation dans MEMORY.md avant de procéder."

**Architecture review finding — Task count scope:**
Original plan resolved counting as "total across all waves" but this only appeared in design docs. Now embedded in Règle #8 text: "tout plan" (unconditional, no counting needed).

---

### File 4: `CLAUDE.md.template` — Shared Files Table Update

Update the existing shared files table (line 354-362) to include the closure relationship:

```
| `.planning/{phase}-SUMMARY.md` | `/gsd:execute-phase` + closure (RULE_4) | `/workflows:review`, `/workflows:compound` |
```

This row either replaces the existing SUMMARY.md reference (line 346) or is added as a new row if not present. The key change is adding "+ closure (RULE_4)" to the producer column.

---

### File 5: `memory/MEMORY.md.template` — New Déviations Section

Insert after "Blocages et questions ouvertes" section (line 43) and before "Patterns découverts cette semaine" (line 46):

```markdown
## Déviations d'exécution

> Effacé en début de session suivante. Max 5 entrées.

| Étape prévue | Action réelle | Raison | Date |
|---|---|---|---|
| — | — | Aucune déviation | {{DATE}} |
```

### Research Insights — MEMORY.md Section

**Context manager skill finding (critical):**
The original plan wrote deviations to "Décisions actives" — this is semantically wrong. That section is for durable decisions that influence code direction (confirmed by the skill's memory layer hierarchy). Deviations are ephemeral process events.

The new dedicated section:
- Is bounded (max 5 entries) — prevents unbounded growth
- Is ephemeral ("Effacé en début de session suivante") — keeps MEMORY.md compact
- Does not pollute "Décisions actives" — preserves signal-to-noise ratio for durable decisions
- Is compatible with checkpoint protocol — checkpoints can skip this section since it's session-scoped
- Separates "what we decided" (Décisions actives) from "where we deviated" (Déviations d'exécution)

---

## Spec-Flow Analysis — Resolved Gaps

### Gap 1: Closure artifact collision with GSD's SUMMARY.md

**Resolution:** RULE_4 does NOT create a new file. It enforces that GSD's existing `.planning/{phase}-SUMMARY.md` must include a planned-vs-actual reconciliation section. If the file exists but lacks the section, the orchestrator adds it before proceeding (recovery path added per architecture review).

### Gap 2: Boundary protection is advisory + surfaced in workflow

**Resolution:** Boundaries section is required in all plans. The detailed workflow block now includes an explicit "lire ## Boundaries du PLAN.md avant la première wave" instruction. This converts the Boundaries section from a passive artifact to an active constraint the orchestrator checks. The escape hatch (deviation logging to MEMORY.md) provides traceability when boundaries are legitimately crossed.

### Gap 3: Deviation definition is precise

**Resolution:** RULE_5 text explicitly lists deviation types AND exclusions. "New implementation files created as part of completing a planned task are NOT deviations" prevents false-positive noise from GSD's normal parallel execution.

### Gap 4: MEMORY.md — correct section with bounded growth

**Resolution:** New "Déviations d'exécution" section in MEMORY.md template. Max 5 entries, cleared each session. Orchestrator writes consolidated deviations at wave completion, not individual subagents mid-execution. No race condition risk.

### Gap 5: Règle #8 enforcement level (CLAUDE.md vs CARL rule)

**Resolution:** Keep Règle #8 in CLAUDE.md.template only. CARL rules enforce runtime behavior; CLAUDE.md governs plan structure. Correct separation of concerns.

### Gap 6: BDD now unconditional

**Resolution:** Every plan gets at least one AC. No threshold to remember or apply.

### Gap 7: Boundaries section required for all plans

**Resolution:** Confirmed — even a 1-task plan benefits from declaring what NOT to touch.

## Dependencies & Risks

**Low risk:**

- Changes only affect the template — no existing projects are modified
- CARL rules are additive (RULE_4/5 don't conflict with RULE_0-3)
- No new files, commands, or dependencies (MEMORY.md template update is a section addition)

**Edge cases handled:**

- CARL not installed: rules don't load, but CLAUDE.md workflow guidance still applies as documentation
- SUMMARY.md content-incomplete: RULE_4 includes recovery path ("add the reconciliation section before proceeding")
- Boundary legitimately crossed: deviation logging provides traceability, doesn't block
- Parallel subagents: orchestrator consolidates deviations at wave completion, no race condition
- Existing projects: not affected (template changes only)
- MEMORY.md growth: Déviations section bounded at 5 entries, cleared per session

## Task List with AC Traceability

| Task | Files | Satisfies |
|---|---|---|
| Add RULE_4 (LOOP CLOSURE) to domain.template | `.carl/domain.template` | AC-1 |
| Add RULE_5 (DEVIATION LOGGING) to domain.template | `.carl/domain.template` | AC-1 |
| Update basic workflow block with closure arrow | `CLAUDE.md.template` | AC-2 |
| Update detailed workflow block with boundary read + closure | `CLAUDE.md.template` | AC-2 |
| Add Règle #8 (BDD + Boundaries) | `CLAUDE.md.template` | AC-3, AC-4 |
| Update shared files table | `CLAUDE.md.template` | AC-2 |
| Add "Déviations d'exécution" section to MEMORY.md template | `memory/MEMORY.md.template` | AC-5 |

## Verification

After implementation:

1. Read `.carl/domain.template` — confirm RULE_4/5 are active with correct text, RULE_6/7/8 are commented slots
2. Read `CLAUDE.md.template` — confirm closure in both workflow blocks, Règle #8 with unconditional BDD + boundaries
3. Read `memory/MEMORY.md.template` — confirm "Déviations d'exécution" section with bounded table
4. Run `init-project.sh "Test" testdomain "test,demo"` in a temp dir — confirm generated files have the rules with substituted domain prefix
5. Delete test project

## References

- Brainstorm: [2026-03-04-paul-cherry-picks-brainstorm.md](docs/brainstorms/2026-03-04-paul-cherry-picks-brainstorm.md)
- PAUL Framework: https://github.com/christopherKahler/paul
- CARL domain template: [.carl/domain.template](.carl/domain.template)
- CLAUDE.md template: [CLAUDE.md.template](CLAUDE.md.template)
- MEMORY.md template: [memory/MEMORY.md.template](memory/MEMORY.md.template)
- Cucumber BDD Anti-Patterns: https://cucumber.io/docs/guides/anti-patterns/
