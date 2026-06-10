---
forge_pattern: "artifact-staleness-watcher"
category: "lifecycle-governance"
reusability: "high"
maturity: "implemented"
authored: "2026-04-12"
implementation_phase: "24.2 (staleness-lifecycle)"
---

# FORGE Pattern: Artifact Staleness Watcher

## Problem

Des artefacts trackés (todos, issues, work items, documents) référencent une entité parente (phase, milestone, sprint, ticket) dont le statut évolue indépendamment. Quand la phase parente est marquée complète, les artefacts fils restent en suspens sans alerte — signalant une dette de triage silencieuse. Avec le temps, les systèmes accumulent des artefacts "fantômes" qui consomment de l'attention sans valeur.

Le pattern `artifact-staleness-watcher` résout ce problème en traitant l'association artifact→parent comme métadonnée first-class dans chaque artefact, en détectant automatiquement les artefacts dont le parent a atteint un état terminal, et en déclenchant un protocole de triage structuré.

## When to use this pattern

- Des artefacts (todos, issues, docs) référencent explicitement une entité parente via un champ structuré (`phase:`, `sprint:`, `milestone:`, `epic:`)
- L'entité parente a un cycle de vie avec un état terminal identifiable (completed, closed, shipped, archived)
- Les artefacts orphelins s'accumulent sans triage naturel
- Vous voulez une détection proactive — pas un audit manuel périodique

## When NOT to use this pattern

- Artefacts sans référence parente explicite (standalone, evergreen)
- Systèmes où les artefacts sont automatiquement supprimés/archivés à la complétion du parent (pas de dette de triage possible)
- Cycle de vie parente non-structuré ou non-versionnable (pas de source de vérité interrogeable)

## Generic architecture

### 1. Artifact frontmatter as parent reference

Chaque artefact porte un champ d'association vers son parent :

```yaml
---
id: {N}
title: "{description}"
status: pending | complete | done
parent_ref: "{parent-identifier}"   # ex: phase: "14", sprint: "S42", epic: "AUTH-1"
created_at: {YYYY-MM-DD}
---
```

Le champ `parent_ref` EST la liaison. Sa valeur doit être normalisée (format canonique, zero-padded, quoted) pour permettre un matching exact sans ambiguïté.

**Anti-patterns courants :**

| Valeur incorrecte | Correct |
|---|---|
| `phase: 4` (integer) | `phase: "04"` (quoted string) |
| `phase: backlog` | `phase: "—"` (standalone) ou vrai numéro |
| `phase: 14-feature-name` | `phase: "14"` (identifiant uniquement) |

### 2. Parent completion detection

Un script de detection parse la source de vérité du parent pour extraire les identifiants en état terminal :

```
completed_parents = parse_completion_markers(source_of_truth)
```

Exemples par système :
- **ROADMAP.md** : regex sur `^\- \[x\] \*\*Phase (\d+)`
- **Linear** : query `issues(filter: {state: {type: {eq: "completed"}}})`
- **GitHub Issues** : `gh issue list --state closed --json number`
- **Jira** : JQL `project = X AND status = Done`

### 3. Staleness cross-reference

```
stale_artifacts = [a for a in pending_artifacts if a.parent_ref in completed_parents]
```

La correspondance doit supporter les variantes de format (avec/sans zero-padding, avec/sans sous-versions) pour éviter les faux négatifs.

### 4. Triage protocol

Chaque artefact stale est présenté avec des options de triage explicites :

| Situation | Action |
|---|---|
| Le travail du parent a résolu l'artefact | Fermer (status → complete) |
| Toujours pertinent, nouveau parent | Reassigner (`parent_ref` → nouveau parent) |
| Toujours pertinent, sans parent cible | Standalone (`parent_ref: "—"`) |
| Obsolète (scope changé, décision annulée) | Fermer avec `reason: obsolete` |

### 5. Proactive alert integration

La détection doit tourner automatiquement — pas uniquement sur demande :

- **Session start hook** : vérification silencieuse au démarrage, alerte si count > seuil
- **Phase closure trigger** : déclencher le triage à chaque complétion de parent
- **Seuil d'alerte** : configurable — typiquement > 5 artefacts stale → warning visible

Format d'alerte minimal :
```
⚠ {N} stale artifact(s) on completed {parent_type}s. Run /{triage_command} to triage.
```

## Reuse guide (how to apply to any repo)

1. **Identifier les artefacts trackés** — todos, issues, documents, runbooks — tout ce qui a une durée de vie liée à un parent.

2. **Choisir le champ d'association** — nommer le champ clairement (`phase:`, `sprint:`, `milestone:`), définir le format canonique (string, quoted, normalisé).

3. **Identifier la source de vérité du parent** — fichier texte, API, base de données. Écrire un parser qui extrait les identifiants en état terminal.

4. **Écrire le cross-reference check** — ~20 lignes de script. Input: liste artefacts + liste parents complétés. Output: count + liste des artefacts stale.

5. **Définir le protocole de triage** — 3-4 options explicites (fermer, reassigner, reclassifier). Documenter comme commande ou sous-commande (ex: `/todo stale`).

6. **Intégrer dans le session start hook** — vérification non-bloquante, warn-only, exit 0 toujours.

7. **Intégrer dans le closure trigger** — déclencher le triage automatiquement quand un parent est marqué complet.

8. **Documenter dans le workflow guide** — ajouter une étape explicite dans le protocole de clôture.

## Extension points

- **Multi-level hierarchy** : un artefact peut avoir un parent et un grand-parent (phase → milestone). Étendre le schema frontmatter avec `parent_hierarchy: [phase, program]`.
- **Cross-system** : artefacts dans Linear/GitHub, parents dans ROADMAP.md locale — le cross-reference script interroge les deux sources.
- **Cascade** : quand un artefact est reassigné à un nouveau parent, vérifier que ce nouveau parent n'est pas lui-même déjà complet.
- **Metrics** : tracker le temps moyen de résolution des artefacts stale par type de parent (leading indicator de dette de triage).
- **Auto-triage** : pour les artefacts sans activité depuis > N jours, proposer automatiquement la fermeture plutôt qu'une liste interactive.

## Related FORGE patterns

- `upstream-source-watcher` — même philosophie (frontmatter as first-class metadata + proactive alert)
- `phase-lifecycle` — source de vérité de completion des parents
- `knowledge-grounding` — vérification proactive vs rationalization silencieuse
