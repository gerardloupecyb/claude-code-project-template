# MEMORY.md — project-template-v2

> Fichier d'état courant. Lu en premier à chaque session.
> Mis à jour en fin de session avant le commit.

---

## État du projet

**Statut :** [ ] En démarrage  [x] En cours  [ ] Bloqué  [ ] Terminé
**Dernière session :** 2026-03-31
**Prochaine étape :** Track A livré (18/18 deliverables). Décider : (1) merge feat/agentdb-track-b → master, (2) lancer Track B si prévu, ou (3) tests d'intégration multi-projets via init-project.sh.

---

## Contexte courant

Template de projet Claude Code avec skills personnalisés (session-gate, context-manager, project-sync, pre-flight, SPARC, todo, prepare-phase) et intégrations CARL/GSD/Codex/AgentDB.

---

## Ce qui a été fait

### 2026-03-31 — Track A: Ruflo concepts integration (18/18 deliverables) — DONE

- SPARC skill (5 phases: spec→pseudo→arch+critic→refine→complete), Codex rescue + adversarial
- prepare-phase orchestrator (discuss→plan→deepen?→pre-flight in one command)
- todo skill (CRUD for todos/ with pending/complete/done subdirs + auto-increment IDs)
- swarm-patterns.md (8 agent roles, 3 topologies, 3-tier model routing)
- pre-flight: Agent 5 Architecture Critic (Opus, dual-agent) + Codex adversarial review
- session-gate: Check 18 (pre-flight detection) + Check 19 (agent spawn audit via pre-agent.sh)
- domain.template: RULE_9 (pre-flight enforcement) + RULE_10 (todo discipline)
- execution-quality.md: ADR auto-tracking section added
- contexts.md.template (DDD bounded contexts), .codex/config.toml.template
- CLAUDE.md.template: /prepare-phase+/sparc workflows, AgentDB replaces Supermemory throughout
- init-project.sh: installs 13 skills, 3 hooks, 4 rules, all new templates; todos/ subdirs
- Committed on feat/agentdb-track-b (commit 627354d)

### 2026-03-16 — Execution quality hybridation (ce-work x GSD) — DONE

- Analyse comparative gsd:execute-phase vs ce-work (forces/faiblesses)
- Décision : hybridation via .claude/rules/ plutôt que remplacement
- Créé `.claude/rules/execution-quality.md` (42 lignes, 630 tokens) — 3 patterns : system-wide test check, post-deploy monitoring, commit heuristics
- CLAUDE.md.template mis à jour (outils actifs + phase exécution)
- Released v2.1.0

### 2026-03-16 — Context management improvements (10/10 DONE)

- Plan créé + deepened avec 7 agents parallèles (14 gaps identifiés, 12 corrections intégrées)
- Branch `feat/context-management-improvements`, 7 commits incrémentaux
- Changes 1-5, 8-9: rules, COT, skills, session-gate checks 9-10, CARL RULE_6/7
- Change 6: hooks pre-compact.sh + session-start.sh + settings.json + init-project.sh updated
- Change 10: GLOBAL_RULE_9 step 6 (MCP discipline auto-update) dans ~/.carl/global + blueprint
- Validation: test project généré, toutes les AC vérifiées, cleanup OK

### 2026-03-31 — DECISIONS.md créé pour ce projet

- Plan 2026-03-16-002 était déjà complété (status: completed-lean)
- DECISIONS.md manquait car projet créé avant la mise à jour du template
- Créé DECISIONS.md avec 7 décisions migrées depuis MEMORY.md (DEC-001 à DEC-007)
- Session-gate vérifié : 17 checks, CARL RULE_8 actif, /project-bootstrap existe

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
| Quality checks CE via rules, pas remplacement GSD | Hybridation : GSD orchestration + ce-work quality patterns injectés via .claude/rules/execution-quality.md | 2026-03-16 |
| AgentDB remplace Supermemory dans tout le template | Supermemory est externe/SaaS, AgentDB est self-hosted + mémoire sémantique | 2026-03-31 |
| Track A sur feat/agentdb-track-b (pas master) | Branche existait déjà — merge à confirmer par l'utilisateur | 2026-03-31 |

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

Pattern découvert : injecter des quality patterns cross-workflow via `.claude/rules/` plutôt que modifier les fichiers source d'un workflow externe (GSD). Le mécanisme rules/ est auto-chargé par tous les subagents.
→ Potentiellement cross-projet si validé en usage réel.

---

## Stack et config

- Claude Code avec CARL (context-aware rules)
- GSD workflow system
- Compound Engineering Plugin v2.40.0
- Variables d'environnement : voir `.env`

---

## Liens utiles

- Projet local : /Users/gerardvinou/Claude code/Claude Projects/project-template-v2

<!-- pre-compact snapshot -->
**Snapshot pre-compaction** (2026-03-31 21:10)

- **Prochaine etape:** (1) merge feat/agentdb-track-b → master, (2) lancer Track B si prévu, ou (3) tests d'intégration multi-projets via init-project.sh.
- **Derniers commits:**
  - 3db3f1f chore: track pre-existing skill files before merge
  - e59ae2c feat: merge feat/agentdb-track-b — Track A (Ruflo concepts) + Track B (AgentDB self-hosted memory)
  - bf81008 chore(agentdb-mcp): add package-lock.json for reproducible MCP client installs
- **Fichiers modifies:**
  - UU .carl/domain.template
  - A  .carl/n8nautomation
  - UU .claude/rules/execution-quality.md
  - A  .claude/rules/model-routing.md
  - M  .claude/rules/tool-routing.md
<!-- /pre-compact snapshot -->
