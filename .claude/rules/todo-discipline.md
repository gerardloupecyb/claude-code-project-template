---
paths:
  - ".planning/todos/**/*.md"
  - ".claude/rules/todo-discipline.md"
  - ".claude/skills/todo/**"
  - ".claude/rules/workflow-guide.md"
  - "docs/architecture/forge/operating-model.md"
  - "docs/solutions/agents/workflow-documents-inventory.md"
---

# Todo discipline — todos/ est géré par le skill /todo uniquement

> **ID scheme (depuis 2026-05-27) : date-prefixé `{YYYY-MM-DD}-{slug}`.** L'ancien scheme numérique
> `MAX+1` collisionnait entre branches parallèles (chaque branche prend le même prochain numéro →
> collision au merge ; ~14 collisions observées 2026-05-26 sur 16–24 branches). Les ids numériques
> legacy restent en place (trouvables par slug, jamais renumérotés). Détail : `.claude/skills/todo/SKILL.md` § create.

IMPORTANT : Ne jamais écrire directement dans `todos/` avec Write ou Edit.
Le skill encapsule le séquençage des IDs, les git mv, et la validation.

## Table de routing

| Situation | Outil correct | Anti-pattern — NE PAS faire |
|-----------|--------------|----------------------------|
| Créer un todo | `/todo create "description"` | `Write todos/pending/X-foo.md` |
| Marquer terminé | `/todo close {ID}` | `Edit todos/pending/X-foo.md` → status: complete |
| Vérifier complété | `/todo done {ID}` | `Bash(git mv todos/complete/... todos/done/...)` |
| Lister les todos | `/todo list` | `Glob todos/**/*` + lecture manuelle |
| Vérifier l'intégrité | `/todo validate` | Scan manuel des IDs |

## Todo-phase association

Chaque todo DOIT avoir un champ `phase:` dans son frontmatter YAML.

**Format canonique :** `phase: "XX.Y"` (numéro de phase entre guillemets, ex: `"04"`, `"14"`, `"04.2"`).
Standalone/ops todos sans phase : `phase: "—"`.

**Anti-patterns — NE PAS faire :**

| Valeur incorrecte | Valeur correcte |
|-------------------|-----------------|
| `phase: 4` | `phase: "04"` |
| `phase: 9` | `phase: "09.1"` |
| `phase: backlog` | `phase: "—"` ou le vrai numéro de phase |
| `phase: done` | `phase: "04.2"` (le numéro, pas le statut) |
| `phase: 14-tenant-foundation-runbook-...` | `phase: "14"` |
| `phase: "02-onboarding-pipeline"` | `phase: "02"` |

**Règles :**
1. Le skill `/todo create` doit toujours inclure `phase:` dans le frontmatter
2. `/todo list` affiche les todos groupés par phase
3. `/todo validate` vérifie que `phase:` est présent et au format canonique
4. Quand un todo est reclassé vers une autre phase, mettre à jour `phase:` dans le même commit

## Staleness lifecycle

Un todo `pending/` dont la phase est marquée `[x]` dans ROADMAP.md est **stale**.
Les todos stale ne doivent pas s'accumuler — ils signalent un oubli de triage à la clôture de phase.

**Trigger :** À chaque phase closure (workflow-guide.md § Closure Protocol step 4b).

**Triage obligatoire pour chaque todo stale :**

| Situation | Action |
|-----------|--------|
| Le travail de la phase a résolu le todo | `/todo close {ID}` |
| Toujours pertinent, cible une autre phase | Mettre à jour `phase:` vers la phase cible |
| Toujours pertinent, pas de phase cible claire | `phase: "—"` (standalone ops) |
| Plus pertinent (scope changé, décision annulée) | `/todo close {ID}` — ajouter `reason: obsolete` dans le body |

**Vérification proactive :** `/todo stale` cross-référence `pending/` contre ROADMAP `[x]` phases.

**Anti-pattern :** Laisser des todos pending sur des phases complétées sans les trier.
Seuil d'alerte : > 5 todos stale → signaler en début de session.
