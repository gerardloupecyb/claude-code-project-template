# Requirements: ruflo concepts integration — project-template-v2

**Defined:** 2026-03-31
**Core Value:** Claude exécute les phases GSD de façon structurée et auditable — micro-exécution SPARC, pre-flight jamais skippé, décisions architecturales tracées, mémoire sémantique fiable.

---

## Milestone 1 — Track A: Template Enrichments

### Swarm Patterns

- [ ] **SWARM-01**: `.claude/rules/swarm-patterns.md` existe et contient les 8 rôles définis (architect, critic, coder, reviewer, tester, security-auditor, spec-writer, logic-planner)
- [ ] **SWARM-02**: Topologie hiérarchique, anti-drift, et shared namespace documentés (3 patterns)
- [ ] **SWARM-03**: Model routing 3-tier (Haiku/Sonnet/Opus) avec règles d'escalade
- [ ] **SWARM-04**: Model routing SPARC par phase avec conditions d'escalade vers Opus
- [ ] **SWARM-05**: Fichier < 80 lignes

### Pre-flight

- [ ] **PREFLT-01**: Agent 5 Critic ajouté dans `.claude/skills/pre-flight/SKILL.md`
- [ ] **PREFLT-02**: Agent 5 reçoit l'output de l'Agent 1 (séquentiel, pas parallèle)
- [ ] **PREFLT-03**: Référence rôle `critic` de swarm-patterns.md
- [ ] **PREFLT-04**: Section "Architecture Challenge" dans le report template
- [ ] **PREFLT-05**: Agent 5 skip si plan trivial (pas de findings Agent 1)
- [ ] **PREFLT-06**: Agent 5 vérifie le fichier `docs/architecture/contexts.md` si existant

### SPARC

- [ ] **SPARC-01**: `.claude/skills/sparc/SKILL.md` créé avec 5 phases (Spec, Pseudo, Arch, Refine, Complete)
- [ ] **SPARC-02**: Phase 3 dual-agent : architect + critic en parallèle (tier 3)
- [ ] **SPARC-03**: Phase 5 dual-agent : reviewer + critic en parallèle (tier 3)
- [ ] **SPARC-04**: Chaque phase attend validation avant la suivante
- [ ] **SPARC-05**: Phase 4 = exécution GSD standard (pas de duplication)
- [ ] **SPARC-06**: Fonctionne standalone sans GSD (Phase 5 seule pour Codex review)
- [ ] **SPARC-07**: Workspace dans `.claude/workspace/sparc-*.md`
- [ ] **SPARC-08**: Fichier < 150 lignes
- [ ] **SPARC-09**: `contexts.md` passé comme contrainte si le fichier existe (Phase 3)

### Pre-flight Enforcement

- [ ] **ENFC-01**: Règle CARL ajoutée — ne pas exécuter /gsd:execute-phase sans fichier *-PREFLIGHT.md
- [ ] **ENFC-02**: Règle actionnable (verbe + condition + action), numéro séquentiel correct
- [ ] **ENFC-03**: Session-gate Check 18 (mode END) — détecte PLAN sans PREFLIGHT
- [ ] **ENFC-04**: Session-gate Check 18 — détecte verdict NO-GO non relancé
- [ ] **ENFC-05**: Check 18 vérifie les deux paths (.planning/ et .planning/milestones/)
- [ ] **ENFC-06**: Message d'erreur actionnable (pas juste un warning)

### Decision Tracking

- [ ] **ADR-01**: Section "Decision Tracking" ajoutée dans `execution-quality.md`
- [ ] **ADR-02**: Skip heuristic documenté (decisions triviales ignorées)
- [ ] **ADR-03**: `execution-quality.md` total reste < 80 lignes

### DDD Léger

- [ ] **DDD-01**: Template `docs/architecture/contexts.md.template` créé avec placeholders
- [ ] **DDD-02**: Pre-flight SKILL.md référence le fichier (Agent 5)
- [ ] **DDD-03**: SPARC SKILL.md référence le fichier (Phase 3)
- [ ] **DDD-04**: Ligne ajoutée dans `execution-quality.md` — vérifier contexts.md avant modification cross-domaine
- [ ] **DDD-05**: Si fichier non rempli, les agents l'ignorent (placeholders = pas de contrainte)

### Agent Spawn Hook

- [ ] **HOOK-01**: `.claude/hooks/pre-agent.sh` créé — log timestamp, type, description
- [ ] **HOOK-02**: `.claude/settings.json` mis à jour avec matcher `Agent` PreToolUse
- [ ] **HOOK-03**: Log dans `.claude/workspace/agent-log.txt`
- [ ] **HOOK-04**: Hook exit 0 toujours (ne bloque jamais)
- [ ] **HOOK-05**: Session-gate Check 19 (END, informational) — compte spawns, alerte si > 15
- [ ] **HOOK-06**: `session-start.sh` vide le log au démarrage (compteur par session)

### Template + Init

- [ ] **TMPL-01**: `CLAUDE.md.template` référence SPARC, swarm-patterns, AgentDB
- [ ] **TMPL-02**: `CLAUDE.md.template` documente le parcours tâche complexe (SPARC flow)
- [ ] **TMPL-03**: `CLAUDE.md.template` < 200 lignes
- [ ] **TMPL-04**: `init-project.sh` copie `docs/architecture/contexts.md.template`
- [ ] **TMPL-05**: `init-project.sh` copie `.claude/hooks/pre-agent.sh`
- [ ] **TMPL-06**: `init-project.sh` met à jour settings.json avec le hook
- [ ] **TMPL-07**: `init-project.sh` ajoute `.claude/workspace/` au .gitignore

---

## Milestone 2 — Track B: AgentDB Self-Hosted

### VPS Infrastructure

- [ ] **VPS-01**: Docker Compose fonctionnel — Qdrant + embedding service + agentdb-api
- [ ] **VPS-02**: Embedding service retourne des vecteurs (modèle nomic-embed-text-v1.5)
- [ ] **VPS-03**: Qdrant accepte et retourne des résultats de recherche
- [ ] **VPS-04**: agentdb-api répond sur les 5 endpoints (store, search, list, delete, reindex)

### MCP Thin Client

- [ ] **MCP-01**: `.claude/mcp/agentdb/` créé avec index.js + package.json
- [ ] **MCP-02**: 5 outils exposés : agentdb_store, agentdb_search, agentdb_list, agentdb_delete, agentdb_debug
- [ ] **MCP-03**: `agentdb_store` écrit fichier local en premier (local-first), puis sync VPS
- [ ] **MCP-04**: `agentdb_debug` retourne les scores bruts pour diagnostiquer
- [ ] **MCP-05**: Config par projet via `.agentdb/config.json` (vps_url, api_key, namespace)
- [ ] **MCP-06**: Si VPS down, store réussit quand même (fichier local créé)

### Entries Format + Git

- [ ] **ENT-01**: Format entrée défini — frontmatter (title, domain, classification, date, author, tags) + sections markdown
- [ ] **ENT-02**: `.agentdb/entries/` est git-tracked
- [ ] **ENT-03**: `.agentdb/config.json` template avec variables (vps_url, api_key as env var)
- [ ] **ENT-04**: `agentdb-reindex.sh` — script de rebuild depuis les fichiers locaux

### Migration Supermemory

- [ ] **MIG-01**: Guide de migration Supermemory → AgentDB documenté
- [ ] **MIG-02**: CLAUDE.md.template référence AgentDB (pas Supermemory)
- [ ] **MIG-03**: `/lesson migrate` pointé vers AgentDB dans flywheel

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Dépendances ruflo (claude-flow MCP, ruv-swarm) | Trop lourd, breaking changes, installation requise par chaque collègue |
| Skill /dual-agent standalone | Redondant avec pre-flight + ce:brainstorm |
| Skill /codex-review standalone | Même mécanique que SPARC Phase 5 |
| DDD tracking complet (comme ruflo) | Trop lourd pour la majorité des projets |
| SQLite local pour AgentDB | Pas de partage entre collègues |
| SPARC qui wrappe /gsd:execute-phase | SPARC = skill indépendant, Phase 4 délègue à GSD standard |

---

## Traceability

### Milestone 1 — Track A

| Requirement | Phase | Status |
|-------------|-------|--------|
| SWARM-01 à SWARM-05 | Phase 1 — swarm-patterns.md | Pending |
| PREFLT-01 à PREFLT-06 | Phase 2 — Pre-flight Agent 5 Critic | Pending |
| SPARC-01 à SPARC-09 | Phase 3 — SPARC Skill | Pending |
| ENFC-01 à ENFC-06 | Phase 4 — Pre-flight Enforcement | Pending |
| ADR-01 à ADR-03 | Phase 5 — Execution Quality + DDD | Pending |
| DDD-01 à DDD-05 | Phase 5 — Execution Quality + DDD | Pending |
| HOOK-01 à HOOK-06 | Phase 6 — Agent Spawn Hook | Pending |
| TMPL-01 à TMPL-07 | Phase 7 — Template + Init | Pending |

### Milestone 2 — Track B

| Requirement | Phase | Status |
|-------------|-------|--------|
| VPS-01 à VPS-04 | Phase 8 — VPS Infrastructure | Pending |
| MCP-01 à MCP-06 | Phase 9 — MCP Thin Client | Pending |
| ENT-01 à ENT-04 | Phase 10 — Entries Format + Git | Pending |
| MIG-01 à MIG-03 | Phase 11 — Migration Supermemory → AgentDB | Pending |

**Coverage Milestone 1:**
- v1 requirements: 41 total
- Mapped to phases: 41
- Unmapped: 0 ✓

**Coverage Milestone 2:**
- v1 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-31*
*Last updated: 2026-03-31 — roadmap created, phase directories initialized*
