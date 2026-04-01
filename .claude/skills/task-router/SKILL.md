---
name: task-router
description: >
  Route les tâches d'un plan GSD vers le modèle approprié (opus/external) et
  génère des context briefs structurés pour les executors externes (Codex VS Code).
  Packaging seulement — review et retry sont gérés par .claude/rules/model-routing.md.
  Trigger: "task-router", "route tasks", "génère les briefs", "prépare pour Codex".
argument-hint: "[plan-path]"
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep, Bash(mkdir *)
---

# Task Router — Générateur de context briefs

Génère des `.task-briefs/` structurés pour les tâches déléguées aux executors externes.

---

## Quand déclencher

- Manuellement via `/task-router` pour pré-générer les briefs
- Quand l'utilisateur dit "route tasks", "génère les briefs", "prépare pour Codex"

> **Note :** L'intégration GSD passe par `.claude/rules/model-routing.md` (auto-chargé), pas par ce skill. Ce skill est un raccourci pour pré-générer tous les briefs d'un coup.

---

## Entrée

Le plan GSD courant. Soit :
- Le plan actif depuis `.planning/` (état GSD)
- Un chemin passé en argument : `/task-router docs/plans/2026-03-20-plan.md`

---

## Étapes

### 0. Créer le dossier de briefs

```bash
mkdir -p .task-briefs
```

### 1. Lire le plan et classifier chaque tâche

Appliquer la classification de `.claude/rules/model-routing.md` :

| La tâche est... | Routing |
|-----------------|---------|
| Architecture, design, review, audit, planification, ambiguë | **opus** → skip (exécuter directement) |
| Implémentation code, scripting, automation, CI/CD, tests | **external** → generate brief |

### 2. Pour chaque tâche "external", construire le context brief

**2a. Identifier les sources de contexte**

Lire `docs/references/Reference-files-index-routing.md` pour déterminer quels fichiers L1-L3 consulter :
- Tâche archi/security → L1 (architecture-security.md)
- Tâche code → L2 (coding-patterns.md) + L3 (codebase-context.md)
- Tâche infra → L3 (services-and-access.md)

> **Guard :** Si `docs/references/` n'existe pas ou contient des placeholders `{{`, skip l'extraction de contexte et noter dans le brief : "Contexte non disponible — fichiers de référence non initialisés."

**2b. Extraire les sections pertinentes (PAS les fichiers entiers)**

De chaque fichier de référence, extraire SEULEMENT les sections pertinentes à la tâche.
Du codebase, extraire SEULEMENT les fonctions/classes que la tâche va modifier ou étendre.

**2c. Écrire le brief**

Écrire `.task-briefs/{NNN}-{slug}.md` :

```markdown
---
status: pending
target_model: codex
---

# Task: {titre}

## Context
[Extraits pertinents de docs/references/ — sections seulement]
[+ Diffs ou snippets des modules/classes que la tâche touche]

### path/to/file.py (lines 45-80)
\```python
# le code pertinent
\```

## Task
[Instructions concrètes, courtes]

## Acceptance Criteria
- [ ] [AC1]
- [ ] [AC2]

## Anti-patterns — DO NOT
- [X parce que Y]
```

**2d. Self-check gate**

Avant de présenter le handoff, répondre à cette question unique :

> "Le brief contient-il tout pour que l'executor produise du code qui compile et passe les AC sans lire d'autres fichiers ?"

Si NON → compléter. Si OUI → continuer.

### 3. Présenter les instructions de handoff

Pour chaque brief généré, afficher :

```
→ Codex VS Code : "lis .task-briefs/{NNN}-{slug}.md et exécute"
```

### 4. Table de routing

Afficher un résumé :

```
| # | Tâche | Routing | Action |
|---|-------|---------|--------|
| 1 | Design API architecture | opus | Exécuter directement |
| 2 | Implement JWT middleware | external | .task-briefs/002-jwt-middleware.md |
| 3 | Write unit tests | opus | Exécuter directement |
```

---

## Ce que ce skill ne fait PAS

- **Review** — géré par model-routing.md (signal `Codex done {slug}`)
- **Retry/Escalade** — géré par model-routing.md (max 2 retries → Opus)
- **Exécuter les tâches opus** — elles passent dans le flow GSD normal

Ce skill ne fait que le packaging. Responsabilité unique.
