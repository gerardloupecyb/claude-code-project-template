---
description: Default to canonical phase orchestrator (/prepare-phase) over sub-step skills (/gsd:plan-phase, /gsd:execute-phase). Substitute only with explicit justification.
paths:
  - ".planning/phases/**/*PLAN*.md"
  - ".planning/phases/**/*CONTEXT*.md"
  - ".planning/phases/**/*SUMMARY*.md"
  - ".planning/phases/**/*VERIFICATION*.md"
  - ".planning/phases/**/*RESEARCH*.md"
  - ".planning/ROADMAP.md"
  - ".planning/STATE.md"
---

# Phase Workflow Orchestrator Default

> Path-scoped : se charge proactivement quand Claude touche un artefact de phase GSD (CONTEXT, PLAN, SUMMARY, VERIFICATION, RESEARCH, ROADMAP, STATE).
> Complète `.claude/rules/workflow-guide.md` § Anti-Patterns ("Do not replace the canonical phase flow with a lighter path") en transformant l'anti-pattern en règle active path-scopée.
> Provenance : `memory/feedback_orchestrator_over_substep.md` (incident Phase 15.1 session 2026-05-11 — l'opérateur a dû corriger l'orchestrateur deux fois pour appliquer la discipline).

## La règle

**Avant de proposer un substep GSD (`/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:discuss-phase`, `/gsd:verify-work`) sur une phase en cours, identifier l'orchestrateur canonique qui le wrappe.**

Si un orchestrateur s'applique et n'est pas terminé : **continuer l'orchestrateur**. Ne pas sauter au substep visible.

Substituer un substep à l'orchestrateur **seulement avec justification explicite** dans le message à l'utilisateur. Jamais en silence.

## Orchestrateurs canoniques

| Situation | Orchestrateur canonique | Substeps wrappés |
|-----------|------------------------|------------------|
| Phase planifiée + à exécuter (CONTEXT.md existe, plans manquants ou à réviser) | `/prepare-phase {N}` (interactive) ou `/prepare-phase {N} --autonomous` (infra phase) | discuss-phase + plan-phase + architecture-kit + document-review + Codex/Gemini adversarial + ce:deepen-plan + pre-flight |
| Phase post-execute (plans done, à clôturer) | Closure protocol de `workflow-guide.md` § Closure Protocol | SUMMARY.md + MEMORY update + verify-work + lessons + todos stale + brainstorm archival + commit-push proposal |
| Phase debug / investigation | `/gsd:debug` (orchestrateur scientific method) | hypothesis + experiment + verify + checkpoint |

## State machine — où suis-je dans l'orchestrateur ?

Quand un orchestrateur est en cours, avant chaque proposition de "next step", expliciter mentalement :

1. **Quel orchestrateur est actif ?** (`prepare-phase`, closure protocol, debug, etc.)
2. **À quel Step suis-je ?** (`Step N/M` du SKILL.md de l'orchestrateur)
3. **Quel est le next Step canonique de l'orchestrateur ?**
4. **Le substep que je suis tenté de proposer est-il EXACTEMENT le next Step de l'orchestrateur, ou un saut ?**

Si saut → STOP, re-cite le SKILL.md de l'orchestrateur, propose le next Step canonique.

## Exemples de violations à reconnaître

| Symptôme | Diagnostic | Correction |
|---|---|---|
| Utilisateur dit "continue phase N" → je propose `/gsd:plan-phase` directement | J'ai sauté `prepare-phase` en pensant que "continue planning" = sub-step planning | Proposer `/prepare-phase {N}` (autonomous si infra, interactive si commerciale) |
| Phase a CONTEXT.md détaillé → je conclus "planning seul suffit" | CONTEXT.md ne remplace pas l'adversarial review + pre-flight | `prepare-phase` reste canonique ; CONTEXT.md détaillé permet juste de skip Step 1 (discuss-phase no-op) |
| Iter 3 plan revision + plan-checker re-PASS → je propose `/gsd:execute-phase --wave 1` | J'ai assumé prepare-phase terminé après iter 3, sans run Step 6 (pre-flight) | Continuer Step 6 (`/pre-flight`) + Step 7 (consolidated report v2) + Step 7.5 (CEO final gate) avant execute |
| Pre-flight CONDITIONAL GO avec residuals → je propose iter 4 OR direct execute | Pre-flight findings se traitent dans la state machine prepare-phase (fix + re-validate), pas en sortie | Proposer surgical amendment + plan-checker re-verify, dans le cadre prepare-phase |
| Phase complete → je propose `/commit-push` sans SUMMARY ou MEMORY update | Closure protocol exige Steps 1-8 dans l'ordre | Run Step 1 (SUMMARY) → Step 2 (MEMORY) → ... → Step 8 (propose commit-push) |

## Justification valide pour substituer un substep

Cas où proposer un substep au lieu de l'orchestrateur est légitime — TOUJOURS avec mention explicite dans la réponse :

- **Utilisateur demande explicitement le sub-step** ("juste lance plan-phase, je sais ce que je fais") → OK, ack la demande + procéder
- **Trivial quick-fix path documenté** (`/gsd:fast` invocation) → OK si user-requested
- **Exemption documentée** dans le CONTEXT.md ou le PLAN.md de la phase (ex: `prepare_phase_waived: true, reason:`) → OK, citer l'exemption
- **Phase déjà partiellement orchestrée et orchestrateur non-resumable** (ex: prepare-phase autonomous a terminé, on est sur une session différente) → OK, citer pourquoi + proposer le sub-step suivant directement

Pas valides comme justification :
- "L'utilisateur a dit 'continue', c'est literally le sub-step suivant" — non, "continue" = intent, pas waiver explicite
- "Le CONTEXT.md est très détaillé donc on peut sauter" — non, voir exemple ci-dessus
- "Iter X a passé donc l'orchestrateur est done" — non, vérifier le state machine du SKILL.md
- "C'est plus rapide" — non, c'est le pattern exact que cette règle adresse

## Anti-patterns à reconnaître chez moi

| Pattern interne | Trigger | Mitigation |
|---|---|---|
| Vouloir proposer "next visible action" | Iter PASS, checker PASS, plan ready | Re-lire le SKILL.md de l'orchestrateur courant pour identifier le vrai next Step |
| Anchoring sur la dernière demande de l'utilisateur | User dit "continue phase 15.1" | Décoder "continue" comme intent stratégique, pas instruction tactique |
| Optimisation locale au détriment du processus | "Wave 1 est read-only donc safe à lancer" | Le safety du sub-step ne justifie pas de skip le pre-flight verdict |
| Mémoire passive non re-lue | Memory existe mais je ne la consulte pas avant la décision | Cette rule path-scopée fire automatiquement → pas de re-lecture manuelle requise |

## Relationship aux autres règles

- **`workflow-guide.md` § Anti-Patterns** — interdit la substitution lighter-path. Cette règle rend l'interdiction active via path-scoping.
- **`verification-discipline.md`** — couvre task-completion claims. Cette règle couvre orchestrator-step claims (les deux sont orthogonaux mais convergents : pas de "ready for next" sans verification).
- **`brief-contract-verification.md`** — couvre brief-vs-source. Cette règle couvre orchestrator-vs-substep. Dans les deux cas : ne pas inventer de raccourci.
- **`phase-lifecycle.md`** — couvre les transitions filesystem (planned/active/complete). Cette règle couvre les transitions workflow (orchestrator state machine).
- **`feedback_orchestrator_over_substep.md`** (memory) — provenance + incident. Garde la mémoire ; cette règle est l'enforcement.

## Règle de maintenance

Mettre à jour ce fichier dans le même commit si :

- Un nouvel orchestrateur canonique est ajouté (ex: nouveau skill `/prepare-X`)
- Un orchestrateur existant change son state machine (steps ajoutés/retirés/réordonnés)
- Un nouveau pattern de violation est identifié et doit être ajouté à la table
- Un nouveau path mérite d'être surveillé (ajouter à `paths:` frontmatter)

## Ce qui ne va pas ici

- Détail du flow de chaque orchestrateur → `.claude/skills/{orchestrator}/SKILL.md`
- Anti-patterns du workflow général (closure, transitions) → `.claude/rules/workflow-guide.md`
- Phase lifecycle filesystem moves → `.claude/rules/phase-lifecycle.md`
- Verification discipline → `.claude/rules/verification-discipline.md`

## Références

- **Source canonique workflow** : `.claude/rules/workflow-guide.md` § Anti-Patterns
- **Orchestrateurs disponibles** : `.claude/skills/prepare-phase/SKILL.md`, `.claude/skills/gsd-debug/SKILL.md`
- **Closure protocol** : `.claude/rules/workflow-guide.md` § Closure Protocol
- **Provenance** : `memory/feedback_orchestrator_over_substep.md` (Phase 15.1 incident 2026-05-11)
