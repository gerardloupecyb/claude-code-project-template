---
title: "feat: Layer 2 retention gaps — decisions, feedback, bootstrap, staleness, cross-projet"
type: feat
status: completed-lean
date: 2026-03-16
deepened: 2026-03-16
implemented: 2026-03-16
scope: lean (post-review simplification)
origin: docs/brainstorms/2026-03-16-layer2-retention-gaps-brainstorm.md
---

## Implementation Status (Lean Scope)

**Implemented (2026-03-16):**

- [x] Change 1 — DECISIONS.md.template (full ADR-light format with active/archived sections)
- [x] Change 1 — init-project.sh generates DECISIONS.md
- [x] Change 1 — CLAUDE.md.template: file table row, Rule de consultation step 2, closure step 7
- [x] Change 1 — MEMORY.md.template: Decisions actives → pointer to DECISIONS.md
- [x] Change 4 (partial) — Session-gate Check 11: DECISIONS.md exists (START+END)
- [x] Change 2 — Closure Quality Score (steps 6-7 in closure protocol)

**Deferred to roadmap (post-review decision):**

- [ ] Change 3 — /project-bootstrap skill (defer until Supermemory reliably available)
- [ ] Change 4 — Checks 12-13 (staleness parsing — low ROI for informational hints)
- [ ] Change 5 — CARL RULE_8 (merge into Rule de consultation instead of separate rule)

**Review rationale:** 3 parallel review agents (architecture, spec-flow, simplicity) recommended cutting ~55% of planned additions. Key findings: /project-bootstrap solves a once-per-project problem with uncertain dependency; Checks 12-13 add parsing complexity for non-blocking `[--]` hints; RULE_8 duplicates the existing Rule de consultation.

---

## Enhancement Summary

**Deepened on:** 2026-03-16
**Research agents used:** 4 — spec-flow analyzer, ADR best practices researcher, skill design reviewer, session-gate check reviewer

### Key Improvements from Deepening

1. **DECISIONS.md format upgraded** — Tags in brackets after title for LLM filtering, explicit "Rejected" field (prevents re-proposal of discarded approaches), active entries at top / archived at bottom
2. **Closure quality score simplified** — Removed "first pass" qualifier (not mechanically determinable) and "/ce:review findings" component (review runs AFTER closure in all workflow parcours)
3. **project-bootstrap skill hardened** — Cap-awareness before injection, expanded Supermemory tag filter, deduplication check, domain-compatible heritage tag format, mechanical selection (date-ranked)
4. **Session-gate Check 12 parsing clarified** — Section-scoped parsing (per `## DEC-` heading), single format only (drop dual-format parsing)
5. **Check 5 planning reminder dropped** — CARL RULE_8 already enforces recall mechanically; Check 5 reminder violates "no semantic judgment" principle and has false-positive risk on French word "plan"
6. **MEMORY.md.template added to files-to-modify** — Was missing; "Decisions actives" section must be updated to pointer format
7. **RULE_8 wording clarified** — "RECALL keywords from manifest" replaces vague "top 3 domain keywords"

### New Considerations Discovered

- Check 5 planning reminder is redundant with CARL RULE_8 and introduces semantic judgment into a mechanical skill — dropped
- `/ce:review` runs AFTER closure in all 3 workflow parcours — quality score cannot include review findings at closure time
- Heritage `[heritage:{source}]` tag would break `/lesson migrate` domain taxonomy — fixed to keep standard `[domaine]` tag with heritage metadata on date line
- DECISIONS.md should have "Rejected" field prominently — LLMs without it will re-propose discarded approaches (most common ADR failure mode for AI)
- `MEMORY.md.template` was not listed in files-to-modify despite the plan saying "Decisions actives becomes a pointer"

# feat: Layer 2 Retention Gaps — 5 Structural Improvements to Project Memory

## Overview

Five targeted improvements to the template's Layer 2 (per-project context) that address gaps NOT covered by the March 16 context-mode plan (002-001). These gaps prevent the template from truly "getting better over time" — decisions get lost, output quality isn't measured, new projects start cold, stale content goes undetected, and cross-project lessons don't propagate.

**Dependency:** Execute AFTER the March 16 context-mode plan (which adds session-gate checks 9-10, CARL RULE_6/7, hooks, and tool routing). This plan adds checks 11-13, RULE_8, and new template artifacts.

(see brainstorm: [docs/brainstorms/2026-03-16-layer2-retention-gaps-brainstorm.md](docs/brainstorms/2026-03-16-layer2-retention-gaps-brainstorm.md))

---

## Problem Statement / Motivation

The existing system is **reactive** — it captures errors after they happen via `/lesson`. But it has 5 structural blindspots:

1. **Decisions evaporate** — MEMORY.md "Decisions actives" table gets cleaned, old decisions vanish, Claude re-proposes rejected approaches
2. **No quality signal** — same vague AC, same plan drift repeat without correction because nothing measures plan quality
3. **Cold start** — new projects have empty LESSONS.md, zero project CARL rules, maximum pain at minimum value
4. **Silent aging** — 30-day-old decisions stay "ACTIVE", outdated lessons go unquestioned
5. **Cross-project amnesia** — Supermemory has lessons but Claude skips the `recall` step at planning time

---

## Proposed Solution — 5 Changes

### Change 1 — DECISIONS.md: Lightweight ADR Register (Gap C)

**New file:** `DECISIONS.md.template` at the root.

**Format — ADR-light with LLM-optimized structure:**

```markdown
# DECISIONS.md — {{PROJECT_NAME}}

> Registre des decisions architecturales et metier.
> Consulte par Claude a la planification (pas chaque session). Cap ~25 decisions actives.
> Les decisions SUPERSEDED/DEPRECATED restent en bas du fichier pour contexte historique.
> Ne jamais supprimer une decision — changer son statut.
> Ne jamais modifier le contenu d'une decision acceptee — seulement son statut.

---

## Decisions actives

<!-- FORMAT pour chaque entree :

### DEC-NNN: Titre court [tag1] [tag2]
- **Date:** YYYY-MM-DD | **Statut:** ACCEPTED
- **Contexte:** Pourquoi cette decision etait necessaire
- **Decision:** Ce qui a ete decide (une phrase)
- **Rejete:** Alternative(s) consideree(s) et pourquoi rejetee(s)
- **Consequences:** Ce que ca implique pour la suite

-->

_Aucune decision pour l'instant — projet en demarrage._

---

## Decisions archivees

<!-- Les decisions SUPERSEDED ou DEPRECATED sont deplacees ici.
     Gardees pour audit trail et pour empecher Claude de re-proposer
     des approches deja rejetees. -->
```

### Research Insights (ADR best practices)

**Format choice rationale:**
- **Tags in brackets** (`[database] [api]`) after the title enable LLM filtering by domain without reading full content
- **One-line "Decision" field** is the most critical for LLM extraction — Claude can scan this without reading context
- **Explicit "Rejected" field** is the most important field for AI consumption — without it, Claude will confidently re-propose discarded approaches (documented as the #1 ADR failure mode for LLM tools)
- **Active decisions at top, archived at bottom** — LLMs read top-down and may truncate, so active decisions must come first
- **`### ` headings** (not `## `) to avoid collision with section headings and enable section-scoped parsing in session-gate
- **Immutability rule** — accepted decision content never changes, only status. This prevents context rot where the decision text drifts from what was actually decided

**References:**
- [ADR Templates — adr.github.io](https://adr.github.io/adr-templates/)
- [The ADR Pattern for Claude — 7tonshark](https://7tonshark.com/posts/claude-adr-pattern/)
- [How to write ADRs — Olaf Zimmermann](https://ozimmer.ch/practices/2023/04/03/ADRCreation.html)
- [AWS ADR Best Practices](https://aws.amazon.com/blogs/architecture/master-architecture-decision-records-adrs-best-practices-for-effective-decision-making/)
- [Claude Code DECISIONS.md Feature Request — GitHub #15222](https://github.com/anthropics/claude-code/issues/15222)

**Lifecycle:**
- **Capture:** During closure protocol (new step 6), any decision noted in MEMORY.md that isn't in DECISIONS.md gets proposed for addition
- **Consultation:** Added to Rule de consultation as step 1.5 (after LESSONS.md, before Supermemory recall)
- **Archival:** No cap-based migration — SUPERSEDED entries stay for context. If file exceeds ~30 ACTIVE entries, review for supersession
- **MEMORY.md change:** "Decisions actives" table becomes a pointer to the 3-5 most recent DEC-NNN entries

**Files to create/modify:**

| File | Action | Details |
|------|--------|---------|
| `DECISIONS.md.template` | **NEW** | ADR-light format, ~30 lines |
| `CLAUDE.md.template` line ~35 | **MODIFY** | Add row to "Fichiers memoire et etat" table |
| `CLAUDE.md.template` lines 362-374 | **MODIFY** | Insert step 1.5 in Rule de consultation |
| `CLAUDE.md.template` lines 93-105 | **MODIFY** | Add step 6 to closure protocol (decision capture) |
| `CLAUDE.md.template` lines 47-50 | **MODIFY** | Update MEMORY.md description to note "Decisions actives" is now a pointer |
| `memory/MEMORY.md.template` lines 32-37 | **MODIFY** | Replace "Decisions actives" table with pointer to DECISIONS.md |
| `init-project.sh` lines ~107-110 | **MODIFY** | Add sed block to generate DECISIONS.md |
| `session-gate/SKILL.md` | **MODIFY** | Add Check 11 (DECISIONS.md exists, START+END) |
| `README.md` | **MODIFY** | Add DECISIONS.md to structure diagram and file table |

### Research Insight: Rule de consultation step renumbering

Inserting "step 1.5" into a numbered markdown list is awkward. The implementation MUST renumber:
- Current step 1 → step 1 (LESSONS.md, unchanged)
- **NEW step 2** → Read DECISIONS.md for active decisions that may constrain the plan
- Current step 2 → step 3 (recall Supermemory)
- Current step 3 → step 4 (agent search docs/solutions/)
- Current step 4 → step 5 (integrate into plan)

---

### Change 2 — Closure Quality Score (Gap B)

**No new file.** Extends the closure protocol in `CLAUDE.md.template`.

**Add step 6 to closure protocol** (after step 5 "tests"):

```markdown
6. Quality score — ajouter dans le SUMMARY.md de la phase :
   ```
   ## Closure Quality Check
   - AC coverage: X/Y AC satisfaits
   - Deviations: N deviations loguees pendant l'execution
   - Verdict: CLEAN | ROUGH
   ```
   - CLEAN = 0 deviations ET tous les AC satisfaits
   - ROUGH = tout le reste
   - Si ROUGH : proposer `/lesson` avec focus "pourquoi le plan n'a pas tenu"
     (remplace la proposition `/lesson` du step 4 pour cette session —
     ne pas proposer deux fois)
```

### Research Insight: Quality score simplified

Two components removed from the original design:

1. **"au premier passage (sans retouche)"** — dropped because there is no mechanical signal to distinguish "AC satisfied first try" from "AC satisfied after rework." The deviation log captures plan divergence, not AC retry attempts. Keeping "first pass" would require semantic judgment, violating the closure protocol's "checklist mecanique" philosophy.

2. **"/ce:review findings"** — dropped because `/ce:review` runs AFTER closure in all three workflow parcours (`closure → /lesson → /gsd:verify-work → /ce:review`). At closure time, review findings are always 0. Moving the quality score post-review would break the closure model.

The simplified score (AC coverage + deviations only) remains fully mechanical and deterministic.

**Add step 7** (decision capture — ties to Change 1):

```markdown
7. Si des decisions ont ete prises pendant l'execution et ne sont pas dans
   DECISIONS.md : proposer l'ajout au format DEC-NNN
```

**Files to modify:**

| File | Action | Details |
|------|--------|---------|
| `CLAUDE.md.template` lines 93-105 | **MODIFY** | Add steps 6 (quality score) and 7 (decision capture) |

---

### Change 3 — `/project-bootstrap` Skill (Gap D)

**New skill:** `.claude/skills/project-bootstrap/SKILL.md`

```markdown
---
name: project-bootstrap
description: "Bootstrap un nouveau projet avec les lecons cross-projet de Supermemory. Se declenche sur : project bootstrap, bootstrap, demarrer le projet. Aussi invoque explicitement avec /project-bootstrap."
---

# /project-bootstrap — Bootstrap cross-projet

Injecte les lecons pertinentes de Supermemory dans LESSONS.md
pour eviter le cold start sur un nouveau projet.

---

## Invocation

| Commande | Effet |
|----------|-------|
| `/project-bootstrap` | Recall Supermemory + injection dans LESSONS.md |

---

## Flux

### Etape 1 — Identifier les keywords

Lire `.carl/manifest` pour extraire les RECALL keywords du projet
(ligne `{DOMAIN}_RECALL=keyword1,keyword2,...`).

Si pas de manifest : proposer des keywords derives du nom du projet,
de la structure de dossiers, et des fichiers CARL existants.
Laisser l'utilisateur confirmer ou ajuster (propose, ne demande pas).

Validation : si les keywords contiennent des valeurs placeholder
(ex: "keyword1", "keyword2"), les rejeter et proposer des alternatives.

### Etape 2 — Recall Supermemory

Appeler `mcp__mcp-supermemory-ai__recall` avec les keywords identifies.
Filtrer les resultats pour les tags :
- `[lesson:*]` — lecons projet
- `[skill:*]` — regles techniques
- `[convention:*]` — facons de travailler
- `[decision:*]` — choix architecturaux

Exclure `[context:preference]` (preferences personnelles, pas transferables).

Si Supermemory indisponible : signaler "Supermemory non disponible —
bootstrap impossible. Le projet demarre a froid." et sortir.

### Etape 3 — Selectionner et verifier le cap

Compter les entrees `###` existantes dans LESSONS.md (hors commentaires HTML).
Calculer la capacite restante : `slots = 50 - existantes`.

Si slots <= 0 : signaler "LESSONS.md est au cap (N/50). Lancer
/lesson migrate avant /project-bootstrap." et sortir.

Parmi les resultats de recall, trier par date decroissante (plus recentes
d'abord). Prendre les min(10, slots) premiers resultats.

Deduplication : exclure les resultats dont le titre correspond a une
entree existante dans LESSONS.md (match exact sur le titre apres `### `).

Presenter la liste a l'utilisateur pour confirmation (deselectionner
les entrees non souhaitees).

### Etape 4 — Injecter dans LESSONS.md

Pour chaque lecon confirmee, ajouter dans LESSONS.md au format standard :

### [domaine] Titre court
**Quand** situation precise
**Faire** action concrete
**Parce que** raison courte
_Date: YYYY-MM-DD | Heritage: {projet-source}_

Le tag `[domaine]` est le domaine technique (api, auth, workflow, etc.),
PAS le nom du projet source. Le projet source est dans la ligne date
(apres `Heritage:`). Ceci preserve la compatibilite avec `/lesson migrate`
qui cree `docs/solutions/{domaine}/lessons-migrated.md`.

Remplacer la ligne "_Aucune lecon pour l'instant..._" si c'est la premiere injection.

### Etape 5 — Rapport

```
Bootstrap termine : N lecons injectees depuis M projets.
LESSONS.md a maintenant T/50 entrees.
Entrees ignorees : D (doublons), S (slots insuffisants).
```

---

## Invocation avancee

| Commande | Effet |
|----------|-------|
| `/project-bootstrap` | Recall + injection (mode standard) |
| `/project-bootstrap --dry-run` | Affiche les lecons candidates sans ecrire |

---

## Ce que ce skill ne fait PAS

- Modifier CARL rules (les lecons heritage sont dans LESSONS.md, pas CARL)
- Ecraser des lecons existantes (ajout seulement, avec deduplication)
- Fonctionner sans Supermemory (degradation gracieuse)
- S'executer automatiquement (invocation manuelle uniquement)
- Depasser le cap de 50 entrees dans LESSONS.md
```

**Files to create/modify:**

| File | Action | Details |
|------|--------|---------|
| `.claude/skills/project-bootstrap/SKILL.md` | **NEW** | ~70 lines, recall + inject |
| `init-project.sh` lines 66-71 | **MODIFY** | Add `mkdir -p "${PROJECT_DIR}/.claude/skills/project-bootstrap"` |
| `init-project.sh` lines 80-91 | **MODIFY** | Add cp for project-bootstrap skill |
| `init-project.sh` lines 161-166 | **MODIFY** | Add "run /project-bootstrap" to next steps echo |
| `README.md` | **MODIFY** | Add project-bootstrap to structure diagram and file table |
| `CLAUDE.md.template` lines 64-67 | **MODIFY** | Add `/project-bootstrap` to workflows "Parcours standard" |

---

### Change 4 — Session-Gate Staleness Checks (Gap E + Gap C support)

**Extends session-gate with 3 new checks** (11, 12, 13). All informational `[--]`.

**Check 11 — DECISIONS.md exists (START, END):**

Read `DECISIONS.md`. Verify file exists and contains at least one markdown heading.
- If missing: `[!!] DECISIONS.md missing — create from template`
- If present: `[ok] DECISIONS.md exists`

**Check 12 — Stale decisions (START, informational):**

For each `### DEC-` heading in `DECISIONS.md`, extract the `**Statut:**` and
`**Date:**` values within that section (stop at the next `### ` heading).
Parse only sections where Statut contains `ACCEPTED`.
Extract the date using pattern `\d{4}-\d{2}-\d{2}` (rejects literal `YYYY-MM-DD`).
Calculate days since date.

- Count entries where date > 30 days
- If count > 0: `[--] N active decisions are > 30 days old — verify if still valid`
- If count == 0 or no ACCEPTED entries: skip (not applicable)

### Research Insight: Section-scoped parsing

Check 12 MUST correlate Date and Statut values within the SAME decision entry.
A naive grep for all date lines + all status lines independently would misattribute
dates to wrong decisions. The section-scoped approach (per `### DEC-` heading,
stop at next `### `) mirrors the pattern already used by Check 3 (deviations)
and Check 4 (ce qui a ete fait) which scope to their respective `## ` sections.

Only one format is parsed (`**Statut:** ACCEPTED` from the deepened template).
The original plan supported a second format (`| Statut | ACTIVE |` table rows)
but the template only produces one format — supporting two adds parsing
complexity for a variant that will never exist in practice.

**Check 13 — LESSONS.md last entry age (START, informational):**

Skip lines between `<!--` and `-->` markers (inclusive).
Then find all lines matching `_Date: \d{4}-\d{2}-\d{2}` in LESSONS.md.
The `\d{4}-\d{2}-\d{2}` pattern naturally rejects the literal `YYYY-MM-DD`
in the template comment block. Extract the most recent date.

Note: heritage entries use `_Date: YYYY-MM-DD | Heritage: {source}_` —
the date regex matches the first date pattern, ignoring trailing content.

- If most recent > 14 days ago: `[--] Last lesson captured N days ago — consider /lesson if any fixes were made`
- If <= 14 days or no entries: skip (not applicable)

**Update invocation table:**
- `/session-gate start` runs: 1, 2, 3, 4, 5, 8, 11, 12, 13
- `/session-gate end` runs: 1, 4, 5, 6, 7, 8, 9, 10, 11
- `/session-gate` (no arg) runs: All 13

**Files to modify:**

| File | Action | Details |
|------|--------|---------|
| `session-gate/SKILL.md` | **MODIFY** | Add Checks 11-13, update invocation table, update section heading "The 13 Checks", update output format example |

---

### Change 5 — CARL RULE_8: Planning Recall Enforcement (Gap A)

**Fill the RULE_8 commented placeholder** in `.carl/domain.template` (after March 16 plan adds RULE_6/7).

```
{{CARL_DOMAIN_UPPER}}_RULE_8=PLANNING RECALL — Before any /gsd:plan-phase, /gsd:discuss-phase, or /ce:plan, run recall on Supermemory with the RECALL keywords from .carl/manifest. Also read DECISIONS.md for active decisions that may constrain the plan. Skip recall only if Supermemory unavailable. This is NOT optional — it prevents rediscovering solved problems.
```

### Research Insight: Check 5 planning reminder dropped

The original plan added a conditional suffix to session-gate Check 5 when
"Prochaine etape" contains "plan." This has been **removed** for three reasons:

1. **Violates "no semantic judgment" principle** — session-gate preamble states
   "All checks are mechanical — no semantic judgment." Scanning content for "plan"
   is a semantic heuristic. French "plan" appears in many non-planning contexts
   ("plan de test", "plan d'action", "floor plan").

2. **Redundant with CARL RULE_8** — the CARL rule fires automatically when
   `/gsd:plan-phase`, `/gsd:discuss-phase`, or `/ce:plan` is invoked. This is
   mechanical and guaranteed. Belt-and-suspenders adds noise without value.

3. **Complicates Check 5 output contract** — Check 5 currently outputs `[ok]`
   or `[!!]`. Adding conditional advice to a pass status creates a hybrid
   output that is neither error nor informational.

### Research Insight: "RECALL keywords from manifest" replaces "top 3 domain keywords"

The original wording "top 3 domain keywords" was vague — no ranking exists.
Changed to "RECALL keywords from .carl/manifest" which is unambiguous: use
all keywords from the `{DOMAIN}_RECALL=` line in the manifest file. This is
the same source `/project-bootstrap` uses (Change 3), ensuring consistency.

**Files to modify:**

| File | Action | Details |
|------|--------|---------|
| `.carl/domain.template` | **MODIFY** | Fill RULE_8 placeholder (line ref removed — will shift after March 16 plan) |
| `.carl/domain.template` | **MODIFY** | Add commented `RULE_9=` placeholder for project-specific use |

---

## System-Wide Impact

### Interaction Graph

- **Closure protocol** (steps 6-7) writes quality score to SUMMARY.md and proposes DECISIONS.md entries
- **Session-gate start** reads DECISIONS.md (Check 11-12) and LESSONS.md dates (Check 13)
- **Session-gate end** validates DECISIONS.md exists (Check 11)
- **Rule de consultation** now includes DECISIONS.md in the read sequence
- **CARL RULE_8** enforces Supermemory recall + DECISIONS.md read at planning time
- **`/project-bootstrap`** reads Supermemory, writes LESSONS.md — no interaction with other changes

### State Lifecycle Risks

- DECISIONS.md has no cap-based migration (unlike LESSONS.md cap 50). Risk: unbounded growth. Mitigation: SUPERSEDED entries provide context but could be pruned via git if file exceeds ~100 entries. Not a near-term concern.
- Heritage entries from `/project-bootstrap` count toward LESSONS.md cap of 50. If 10 heritage + 40 organic = cap reached. Mitigation: heritage entries migrate normally via `/lesson migrate`.

### API Surface Parity

No external APIs affected. All changes are template-level (markdown files, skill definitions, CARL rules).

---

## Acceptance Criteria

### Change 1 — DECISIONS.md

- [ ] `DECISIONS.md.template` exists with LLM-optimized ADR format (tags in brackets, explicit Rejected field, active/archived sections)
- [ ] `init-project.sh` generates `DECISIONS.md` from template with correct sed substitutions
- [ ] `CLAUDE.md.template` "Fichiers memoire et etat" table includes DECISIONS.md row
- [ ] `CLAUDE.md.template` Rule de consultation renumbered: DECISIONS.md is step 2, Supermemory recall becomes step 3, etc.
- [ ] `CLAUDE.md.template` closure protocol has step 7: decision capture proposal
- [ ] `memory/MEMORY.md.template` "Decisions actives" section updated to pointer format referencing DECISIONS.md
- [ ] Session-gate Check 11 validates DECISIONS.md exists

### Change 2 — Closure Quality Score

- [ ] `CLAUDE.md.template` closure protocol has step 6 with simplified quality score (AC coverage + deviations only, no review findings)
- [ ] Verdict logic documented: CLEAN = 0 deviations + all AC satisfied; ROUGH = else
- [ ] ROUGH verdict triggers `/lesson` proposal focused on plan quality (replaces step 4 proposal for that session)

### Change 3 — /project-bootstrap

- [ ] `.claude/skills/project-bootstrap/SKILL.md` exists with recall + inject flow
- [ ] Skill handles Supermemory unavailable gracefully (reports and exits)
- [ ] Heritage entries use standard `[domaine]` tag with `Heritage: {source}` on date line (NOT `[heritage:{source}]` tag)
- [ ] Skill has cap-awareness: checks LESSONS.md count before injection, refuses if cap reached
- [ ] Skill has deduplication: skips entries whose title already exists in LESSONS.md
- [ ] Supermemory tag filter includes `[lesson:*]`, `[skill:*]`, `[convention:*]`, `[decision:*]`
- [ ] Selection is mechanical: date-ranked descending, user deselects unwanted entries
- [ ] Keyword fallback uses propose-then-confirm pattern (not open-ended question)
- [ ] `--dry-run` variant previews without writing
- [ ] `init-project.sh` copies the skill and mentions it in next steps output
- [ ] `README.md` updated with project-bootstrap in structure diagram

### Change 4 — Session-Gate Staleness

- [ ] Session-gate has 13 checks total (was 10)
- [ ] Check 11: DECISIONS.md exists (`[ok]`/`[!!]`, START+END)
- [ ] Check 12: Stale decisions > 30 days, section-scoped parsing per `### DEC-` heading (`[--]`, START only)
- [ ] Check 13: LESSONS.md last entry age, date regex `\d{4}-\d{2}-\d{2}`, handles heritage format (`[--]`, START only)
- [ ] Invocation table updated for all three modes (start/end/both)

### Change 5 — CARL RULE_8

- [ ] `.carl/domain.template` RULE_8 is active with planning recall enforcement using "RECALL keywords from manifest"
- [ ] RULE_9 placeholder exists (commented) for project-specific use
- [ ] No session-gate Check 5 modification (planning reminder dropped — CARL RULE_8 is sufficient)

---

## Boundaries

These files MUST NOT be modified:

- `.claude/skills/lesson/SKILL.md` (not in scope)
- `.claude/skills/pre-flight/SKILL.md` (not in scope)
- `.claude/skills/project-sync/SKILL.md` (not in scope)
- `.claude/skills/context-manager/SKILL.md` (modified by March 16 plan, not this one)
- `.claude/hooks/` (created by March 16 plan, not this one)
- `.claude/rules/tool-routing.md` (created by March 16 plan)
- `memory/MEMORY.md` (live state, not template)
- `LESSONS.md` (live state, not template)

---

## Implementation Order

Execute in this order to minimize rework:

1. **Change 1a** — Create `DECISIONS.md.template` (no dependencies)
2. **Change 1b** — Update `init-project.sh` to generate DECISIONS.md (depends on 1a)
3. **Change 5** — Fill CARL RULE_8 in domain.template + add RULE_9 placeholder (independent)
4. **Change 3** — Create `/project-bootstrap` skill + update init-project.sh (independent)
5. **Change 2** — Add closure quality score steps 6-7 to CLAUDE.md.template (independent)
6. **Change 1c** — Update CLAUDE.md.template: file table row, Rule de consultation step 1.5, MEMORY.md pointer note (depends on 1a)
7. **Change 4** — Add session-gate checks 11-13 + update invocation table + planning reminder on Check 5 (depends on 1a for DECISIONS.md reference)
8. **Change 1d + README** — Update README.md with new artifacts (depends on all above)
9. **Validation** — Generate test project, verify DECISIONS.md created, session-gate reports 13 checks, CARL RULE_8 active

---

## Dependencies & Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| March 16 plan not yet executed — session-gate checks 9-10 missing | Medium | This plan adds checks 11-13 which are independent. Number correctly regardless |
| DECISIONS.md adds CLAUDE.md lines (table row + consultation step + closure step) | Low | Net ~6 lines — offset by March 16 flywheel extraction (-76 lines) |
| `/project-bootstrap` Supermemory not available on new project | Medium | Graceful degradation — reports unavailable and exits. Project starts cold as before |
| Check 12 date parsing fragile (multiple table formats possible) | Medium | Standardize on single format in template. Parse `| Date | YYYY-MM-DD |` pattern only |
| DECISIONS.md file grows unbounded (no cap-based migration) | Low | ~30 ACTIVE decisions is a soft guideline. SUPERSEDED entries add context. Prune via git if needed |
| Closure steps 6-7 add overhead to every execution | Low | Step 6 is mechanical (count AC/deviations/findings). Step 7 is a proposal, not a requirement |

---

## Sources & References

### Origin

- **Brainstorm document:** [docs/brainstorms/2026-03-16-layer2-retention-gaps-brainstorm.md](docs/brainstorms/2026-03-16-layer2-retention-gaps-brainstorm.md) — Key decisions: DECISIONS.md ADR-light (Gap C), mechanical CLEAN/ROUGH score (Gap B), /project-bootstrap via Supermemory recall (Gap D), informational staleness checks (Gap E), CARL RULE_8 enforcement (Gap A)

### Internal References

- `CLAUDE.md.template` — closure protocol (lines 93-105), Rule de consultation (lines 362-374), file table (lines 28-38)
- `session-gate/SKILL.md` — current 10 checks, invocation table (lines 16-19)
- `.carl/domain.template` — RULE_8 placeholder (line 31)
- `init-project.sh` — sed pattern (lines 95-134), skill copy (lines 80-91)
- `LESSONS.md.template` — format reference for heritage entries
- March 16 plan: [docs/plans/2026-03-16-001-feat-context-mode-template-improvements-plan.md](docs/plans/2026-03-16-001-feat-context-mode-template-improvements-plan.md) — prerequisite, adds checks 9-10, RULE_6/7, hooks

### External References

- ADR Templates: [adr.github.io/adr-templates](https://adr.github.io/adr-templates/) — format comparison (Nygard, MADR, Y-statements)
- The ADR Pattern for Claude: [7tonshark.com](https://7tonshark.com/posts/claude-adr-pattern/) — LLM-specific ADR patterns
- ADR Best Practices: [Olaf Zimmermann](https://ozimmer.ch/practices/2023/04/03/ADRCreation.html) — common mistakes and anti-patterns
- AWS ADR Process: [aws.amazon.com](https://aws.amazon.com/blogs/architecture/master-architecture-decision-records-adrs-best-practices-for-effective-decision-making/)
- Claude Code DECISIONS.md: [GitHub #15222](https://github.com/anthropics/claude-code/issues/15222) — feature request for native support
- ADR Creator Skill: [mcpmarket.com](https://mcpmarket.com/tools/skills/adr-creator-3) — existing Claude Code skill for reference
- AI Agent Memory Files: [medium.com](https://medium.com/data-science-collective/the-complete-guide-to-ai-agent-memory-files-claude-md-agents-md-and-beyond-49ea0df5c5a9)
