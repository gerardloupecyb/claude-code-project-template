# MEMORY.md — project-template-v2

> Fichier d'état courant. Lu en premier à chaque session.
> Mis à jour en fin de session avant le commit.

---

## État du projet

**Statut :** [ ] En démarrage  [x] En cours  [ ] Bloqué  [ ] Terminé
**Dernière session :** 2026-03-16
**Prochaine étape :** Implémenter Change 6 — hook scripts (pre-compact.sh, session-start.sh) + settings.json + update init-project.sh

---

## Contexte courant

Template de projet Claude Code avec skills personnalisés (session-gate, context-manager, project-sync, pre-flight) et intégrations CARL/GSD.

---

## Ce qui a été fait

### 2026-03-16 — Context management improvements (7/10 changes done)

- Plan créé + deepened avec 7 agents parallèles (14 gaps identifiés, 12 corrections intégrées)
- Branch `feat/context-management-improvements` créée, 5 commits incrémentaux
- Change 9: markers pre-compact dans MEMORY.md.template
- Change 5: CARL RULE_6 (tool routing) + RULE_7 (MCP discipline) dans domain.template
- Change 1: .claude/rules/tool-routing.md créé + flywheel extrait (CLAUDE.md 505→435 lignes)
- Change 2: Rule #4 COT 2-of-5 triggers + <plan> XML + précédence Override>Skip>Triggers
- Change 3: /context-checkpoint skill créé
- Change 8: context-manager SKILL.md mis à jour (hooks, /context-checkpoint, refs #1-#8)
- Change 4: session-gate Checks 9 (COT docs/plans/) + 10 (LESSONS quality)
- **RESTANT:** Change 6 (hooks + init-project.sh), Change 10 (CARL GLOBAL doc), Validation

### 2026-03-13 — Initialisation

- Structure projet créée depuis project-template/
- Mise à jour du plugin compound-engineering (v2.40.0 — 47 skills, 28 agents)
- Création du MEMORY.md depuis le template

---

## Décisions actives

| Décision | Raison | Date |
|----------|--------|------|
| CARL RULE_6/7 (pas 8/9) | Dernier actif = RULE_5, séquentiel | 2026-03-16 |
| Check 9 cible docs/plans/ (pas PLAN.md) | PLAN.md n'existe pas dans le template | 2026-03-16 |
| trap exit 0 (pas set -euo pipefail) | Hooks doivent toujours exit 0 | 2026-03-16 |
| 4 matchers SessionStart | resume + clear ajoutés en plus de startup + compact | 2026-03-16 |
| git add scopé MEMORY+LESSONS only | Eviter staging de fichiers en cours d'écriture | 2026-03-16 |
| Flywheel extrait vers .claude/rules/ | CLAUDE.md 505 lignes dépasse le budget 200 d'Anthropic | 2026-03-16 |

---

## Blocages et questions ouvertes

- [ ] Aucun blocage actuel

---

## Déviations d'exécution

> Vidé en début de session suivante. Max 5 entrées.
> Si la table atteint 5 entrées, signaler que le plan nécessite révision.

| Étape prévue | Action réelle | Raison | Date |
|---|---|---|---|

---

## Patterns découverts cette semaine

Aucun pattern à capitaliser pour l'instant — projet en démarrage.
→ À traiter au prochain /workflows:compound

---

## Stack et config

- Claude Code avec CARL (context-aware rules)
- GSD workflow system
- Compound Engineering Plugin v2.40.0
- Variables d'environnement : voir `.env`

---

## Liens utiles

- Projet local : /Users/gerardvinou/Claude code/Claude Projects/project-template-v2
