# Workflow Guide — Operating Rules

> Concise operating behavior only. Detailed architecture, flows, deliverables,
> and enforcement live in `docs/architecture/workflow-architecture.md`.

## Scope And Precedence

- This file: auto-injected runtime rules (path selection, closure, transitions)
- `docs/architecture/workflow-architecture.md`: canonical system architecture and phase flows
- On conflict, `workflow-architecture.md` wins for system descriptions

## State Files

- `memory/MEMORY.md` — session journal (manual update at session start/end)
- `LESSONS.md` — task-scoped lesson cache (cap 50); read before implementation, review, debug, fix
- `DECISIONS.md` — active architectural decisions (cap ~25)
- `.planning/STATE.md` — GSD technical position (auto-managed)

MEMORY hygiene:
- Cap 8 sessions in "Ce qui a ete fait"; archive surplus to `memory/archive-YYYY-MM.md`
- Archive at session end (closure step 2)

## Path Selection

- Active GSD phase or explicit numbered phase request → follow `workflow-architecture.md` §3
- No active GSD phase → follow `workflow-architecture.md` §1 "Path Selection Outside GSD"
- If `docs/brainstorms/*-brainstorm.md` exists (< 7 days), read it before `/prepare-phase` (orchestrator) or its substeps `/gsd:discuss-phase` / `/gsd:plan-phase`

### Upstream of GSD

Canonical flow for pre-phase artifacts:

```
ce:ideate → docs/ideation/       (raw idea capture, status: active at root)
   │
   │ promote (`git mv` to `docs/ideation/brainstormed/`, set status: brainstormed + promoted_to:)
   ▼
ce:brainstorm → docs/brainstorms/  (structured brainstorm, status: active at root, < 7 days cap)
   │
   │ link (`git mv` to `docs/brainstorms/linked/`, set status: linked + linked_phase:)
   ▼
/gsd:add-phase → .planning/phases/planned/{phase}/   (phase CONTEXT.md references the brainstorm as `origin:`)
```

**Directory nomenclature (status-based, mirrors `.planning/phases/`):**

| Dir | Status at root | Subdirs (status) |
|-----|---------------|------------------|
| `docs/ideation/` | `active` (< 30 days) | `brainstormed/` (promoted to a brainstorm), `archived/` (retired) |
| `docs/brainstorms/` | `active` (< 7 days) | `linked/` (consumed by a GSD phase), `archived/` (phase complete), `rejected/` (did not convert) |

**Transitions (always `git mv`, never copy+delete):**

- Ideation → brainstorm: `git mv docs/ideation/{file}.md docs/ideation/brainstormed/`, set `status: brainstormed` + `promoted_to:` in frontmatter, create the new brainstorm under `docs/brainstorms/` with `origin:` backlink.
- Brainstorm → phase: `git mv docs/brainstorms/{file}.md docs/brainstorms/linked/`, set `status: linked` + `linked_phase: "XX.Y"`, reference the brainstorm as `origin:` in the phase CONTEXT.md.
- Brainstorm post-phase-closure: `git mv docs/brainstorms/linked/{file}.md docs/brainstorms/archived/`, set `status: archived` + `archived_on:`.
- Brainstorm rejected: `git mv docs/brainstorms/{file}.md docs/brainstorms/rejected/`, set `status: rejected` + `rejected_reason:`.
- Ideation retired (never became a brainstorm, > 30 days stale): `git mv docs/ideation/{file}.md docs/ideation/archived/`, set `status: archived` + `archived_on:`.

**Frontmatter schema:** canonical in `docs/references/source-of-truth-map.md` § "Frontmatter Schema".

**Existing brainstorms at the root** (pre-Phase-24.6): left in place. Migration is lazy — apply the new schema only when a file is next touched or its linked phase closes.

- Do not substitute a lighter path unless an exemption is documented
- `/gsd:fast` is only valid when the user explicitly requests the trivial quick-fix path

## Phase Preparation — Default Orchestrator

For preparing a GSD phase (Steps 0→7: context capture, discuss, plan, document review, cross-model adversarial, deepen, pre-flight) the **canonical entry point is `/prepare-phase`**, never the GSD substeps in isolation.

- `/prepare-phase {N}` — interactive (default)
- `/prepare-phase {N} --autonomous` — zero-prompt mode

**Never propose `/gsd:discuss-phase`, `/gsd:plan-phase`, or `/gsd:research-phase` as standalone first actions** when preparing a phase. Use `/prepare-phase`. Exemptions (must be explicit):

| Exemption | When | What to do |
|---|---|---|
| Explicit user invocation | User typed `/gsd:plan-phase N` directly | Run the substep as requested |
| Surgical re-plan | PLAN.md already exists and was reviewed, only a small section needs refresh | Run `/gsd:plan-phase N`, note exemption in commit message |
| Substep failure recovery | `/prepare-phase` errored on a specific step | Re-run only the failed substep, then resume orchestrator |
| Execution-only handoff | PLAN.md exists + pre-flight passed | Skip prep, go directly to `/gsd:execute-phase` |

When in doubt: propose `/prepare-phase`. Substeps standalone bypass cross-model adversarial review (Codex + Gemini) and pre-flight — which is exactly the discipline failure mode this rule addresses.

## Executor Routing

- `/gsd:execute-phase` is only valid when the selected phase has already satisfied its required planning steps
- `/gsd:fast` is only valid when explicitly requested by the user
- Do not ask the user to choose an executor — infer from context and inform
- Avant de lancer `/gsd:execute-phase` : lire le PLAN.md, et si les steps impliquent des commandes shell composées (`&&`, `$(…)`, `if/then/fi`, assignations + pipes), proposer le worktree sandbox avant de commencer (voir § Worktree Sandbox — Trigger 2)

## Closure Protocol

After every phase execution or significant task: **canonical entry point is `/close-phase {N}`** which orchestrates all the steps below in sequence. The individual steps remain authoritative as the underlying spec — `/close-phase` is the wrapper, not a substitute.

When to invoke substeps standalone vs orchestrator:

| Exemption | When | What to do |
|---|---|---|
| Explicit user invocation | User typed `/lesson`, `/todo stale`, `/commit-push` directly | Run the substep as requested |
| Partial closure (mid-wave) | Phase not fully executed, only progress logging needed | Run `/close-phase {N} --partial` |
| Substep failure recovery | `/close-phase` errored on a specific step | Re-run only the failed substep, then resume orchestrator |

When in doubt: propose `/close-phase {N}`. Substeps standalone bypass the conditional `/{{project}}:review` trigger, the multi-select end-of-closure prompt, the path manifest accumulation, and the canonical folder migration `active/ → complete/` — same discipline pattern as `/prepare-phase` for the prep side.

The detailed steps below describe what `/close-phase` orchestrates internally:

1. Write `.planning/phases/{phase-name}/{N}-SUMMARY.md` (phase-level, not per-plan)
2. Update `memory/MEMORY.md`; archive if > 8 sessions
3. Log deviations in MEMORY.md when relevant
4. Capture lesson via `/lesson` if non-trivial fix or pattern discovered
4b. Run `/todo stale` — triage pending todos on the completed phase (see `todo-discipline.md` § "Staleness lifecycle")
4c. Upstream-of-GSD archivage (opt-in) — propose `git mv` of the linked brainstorm to `docs/brainstorms/archived/` and set `status: archived` + `archived_on:`. Same for any orphan ideation under `docs/ideation/` older than 30 days → `docs/ideation/archived/`. This step is a **proposal**, never automatic — user confirms before any `git mv`. See `workflow-guide.md` § Upstream of GSD for transition mechanics.
4d. Architecture artefact reconciliation — if the phase touched a durable **capability**, run `/architecture-kit {capability-slug} --update` (kit exists) or propose creating one (no kit yet — never skip silently). Skip only for doc-only / refactor / tooling phases. The slug is a feature name, never a phase number. Orchestrated by `/close-phase` Step 4b.
5. Run available tests; fix failures before claiming completion
6. Run `/gsd:verify-work` inside GSD phases
7. If archival happened, run `/knowledge-sync --collection knowledge` to index the new archive file
7b. If architecture artefacts were created or modified, run `/graphify docs/architecture/{slug}/ --update --no-viz` to sync the knowledge graph (post-commit hook handles code + structural docs, but explicit sync catches semantic enrichment for new arch docs)
7c. If governance documents were created or superseded this session, update `docs/GOVERNANCE.md` in the same commit (see `.claude/rules/governance-index-discipline.md`)
8. Propose `/commit-push` — "Commit et push ?" — exécuter seulement si l'utilisateur confirme

## Coordination GSD ↔ CE

- GSD planning reads `docs/brainstorms/`, `docs/plans/`, `docs/solutions/` when relevant
- CE review reads `.planning/{phase}-VERIFICATION.md` and `*-SUMMARY.md`
- CE compound reads `.planning/{phase}-PREFLIGHT.md` when relevant (resolved findings = patterns to capitalize)
- Do not duplicate artifacts across GSD and CE outputs

## Transition Rules

- Propose `/{{project}}:review` after significant execution (> 3 files) or security-sensitive changes
- `/{{project}}:review` ends with a deterministic SAST backstop (Step 8, `sast-scanner` on the diff) AFTER the semantic + cross-vendor consensus passes, then emits a merge-readiness verdict — this is the canonical pre-merge security gate. Do not propose merge/PR until that verdict is `merge-ready`
- If the diff touched `.claude/` (skills, hooks, settings, permissions, agents, commands), propose `/security-audit` (AgentShield — audits the agent config, NOT the code) before merge ({{project}}:review Step 9 surfaces this). AgentShield is **mandatory before `/promote`** of any agentic artefact regardless
- Propose `/lesson` after non-trivial fixes or newly discovered patterns
- After clean review (merge-ready verdict, 0 P1), propose the next normal step (PR, next phase)
- After `/prepare-phase` returns the pre-flight verdict (GO / CONDITIONAL GO / NO-GO), propose execution
- After `/ce:plan` returns, propose execution
- If `/gsd:plan-phase` ran standalone (exemption documented), propose `/pre-flight` BEFORE proposing execution — never skip the gate
- Transitions are proposals, not automatic execution — always confirm first
- Do not repeat a declined proposal in the same session
- After a phase closes with a linked brainstorm, propose step 4c (brainstorm archival) before the commit

## Worktree Sandbox — proposition proactive

### Trigger 1 — Implémentation volumineuse ou domaine protégé

Proposer un worktree isolé avec `--dangerously-skip-permissions` quand les 3 conditions sont réunies :

1. **Volume** : la tâche touche > 5 fichiers OU implique une exécution longue (Pester, déploiement, batch refactor)
2. **Domaine protégé** : la tâche déclenche un skill gate (`{{cloud_provider}}`, `{{WORKFLOW_ENGINE}}`, `{{crm_platform}}`) ou touche des scripts de promotion/déploiement
3. **Réversibilité** : les changements peuvent être mergés vers main via `git merge --no-ff` après validation

Ne PAS proposer ce trigger si la tâche touche < 5 fichiers et ne nécessite pas de déploiement.

### Trigger 2 — Investigation shell-intensive

Proposer un worktree avec `--dangerously-skip-permissions` quand les 3 conditions suivantes sont réunies :

1. **Intent d'audit / investigation / post-mortem** : vérifier un état, tracer un diff, comparer des commits, auditer une phase, post-mortem d'une régression
2. **Shell chaîné complexe** : la tâche implique au moins un de ces patterns — pipelines avec `$(...)`, tests `[ ]`, blocs `if/then/fi`, regex multi-grep enchaînés, assignations de variables intermédiaires, ou plus de 3 `&&` chaînés
3. **Read-only attendu** : commandes de lecture / inspection / diff, aucune écriture vers `main` ni mutation de prod prévue

**Raison (D-A5)** : Claude Code matche la commande complète, pas ses sous-parties. Les commandes composées avec control-flow ne peuvent pas être whitelistées proprement — chaque ajout à l'allow list est un whack-a-mole bloqué par l'audit hook (`config-change-audit.sh`). Au-delà de ~3 prompts répétés dans une session, la friction devient contre-productive. Le sandbox `--dangerously-skip-permissions` élimine structurellement le problème en isolant l'environnement d'inspection.

**Ne PAS proposer Trigger 2** si :
- La tâche ne nécessite aucune exécution shell (raisonnement pur, lecture de fichiers via `Read` tool seulement)
- L'utilisateur est déjà dans un worktree (`git rev-parse --git-common-dir` ≠ `.git`)
- L'utilisateur a explicitement opté out dans la session courante

**Format de proposition Trigger 2** (D-A3) :

```
Cette investigation chaîne du shell complexe (pipes, tests, control-flow).
→ Sandbox recommandé — lecture seule, aucun merge à prévoir.
  Créer `{{project}}-sandbox-audit` sur branche `sandbox/audit-{slug}` ? [y/N]
```

### Format de proposition commun

```
Cette tâche [touche [domaine] avec [N fichiers] / implique des commandes shell composées pour [traçage/vérification/diff]].
→ Worktree sandbox recommandé pour aller vite sans friction.
  Créer `{{project}}-sandbox-phase{N}-{slug-court}` sur branche `gsd/phase-{N}-{slug-complet}` ? [y/N]
```

**Naming canonique obligatoire** (voir `parallel-worktree-discipline.md` R5) :

- Dossier : `{{project}}-sandbox-phase{N}-{slug-court}` (ex: `{{project}}-sandbox-phase14.2-runbook-mode-contract`)
- Branche : `gsd/phase-{N}-{slug-complet}` (slug complet de la phase, sans troncation)
- `{slug-court}` = slug de la branche tronqué à ~25-30 caractères, en gardant les premiers tokens significatifs et en supprimant les modifiers de queue (`-hardening`, `-enforcement`, `-refactor`, `-ingestion`, `-full`, `-{{hosting_vendor}}`, `-on-{{project}}-tenant`)
- Jamais `{{project}}-sandbox` seul, jamais `{{project}}-phase{N}-*` sans `sandbox`, jamais sans slug

Setup documenté dans `memory/project_worktree_sandbox_for_implementation.md`.
La proposition est un signal, pas une obligation — l'utilisateur peut refuser.

## Anti-Patterns

- Do not propose `/gsd:discuss-phase`, `/gsd:plan-phase`, or `/gsd:research-phase` as standalone first actions when preparing a phase — use `/prepare-phase` (see § Phase Preparation — Default Orchestrator)
- Do not replace the canonical phase flow with a lighter path unless exemption documented
- Do not duplicate architecture detail from `workflow-architecture.md`
- Do not skip pre-flight for a planned phase unless exemption documented
- Do not skip closure after phase execution
- Do not rationalize skipping review for significant code changes

## Related Sources

- Detailed workflow architecture: `docs/architecture/workflow-architecture.md`
- Document governance and ownership: `docs/references/source-of-truth-map.md`
- Skill and workflow governance: `.claude/rules/governance.md`
- Model and executor routing: `.claude/rules/router-rules.md`
- Upstream-of-GSD lifecycle (ideation, brainstorm): `docs/references/source-of-truth-map.md` § Frontmatter Schema
