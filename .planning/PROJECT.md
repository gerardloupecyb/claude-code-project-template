# project-template-v2 — ruflo concepts integration

## What This Is

Enrichissement du `project-template-v2` par intégration des concepts clés de ruflo (sans aucune dépendance), réparti en deux milestones : Track A (9 améliorations template) et Track B (AgentDB self-hosted remplaçant Supermemory). Le résultat est un template Claude Code avec micro-exécution structurée (SPARC), conventions multi-agent formalisées, enforcement pre-flight mécanique, ADR auto-tracking, DDD léger, et mémoire sémantique débuggable.

## Core Value

Claude exécute les phases GSD de façon structurée et auditable — micro-exécution SPARC, pre-flight jamais skippé, décisions architecturales tracées, mémoire sémantique fiable.

## Requirements

### Validated

- ✓ GSD workflow (roadmap, phases, plans) — existing
- ✓ CARL rules system — existing
- ✓ Session-gate (17 checks) — existing
- ✓ Pre-flight skill (4 agents) — existing
- ✓ execution-quality.md rules — existing
- ✓ Hooks system (session-start, pre-compact) — existing

### Active

**Milestone 1 — Track A: Template Enrichments**

- [ ] swarm-patterns.md — conventions multi-agent, rôles, topologie, model routing (< 80 lignes)
- [ ] Pre-flight Agent 5 Critic — challenger l'Agent 1 Architecture, intégration DDD
- [ ] SPARC skill — micro-exécution 5 phases dans une phase GSD (< 150 lignes)
- [ ] CARL rule — enforcement pre-flight avant /gsd:execute-phase
- [ ] Session-gate Check 18 — détection pre-flight absent ou NO-GO non relancé
- [ ] Session-gate Check 19 — agent spawn audit (informational)
- [ ] Hook PreToolUse Agent — log des spawns dans .claude/workspace/agent-log.txt
- [ ] execution-quality.md — section Decision Tracking (ADR auto)
- [ ] DDD léger — docs/architecture/contexts.md.template + intégrations pre-flight et SPARC
- [ ] CLAUDE.md.template + init-project.sh — références SPARC, AgentDB, nouveaux fichiers

**Milestone 2 — Track B: AgentDB Self-Hosted**

- [ ] VPS Setup — Qdrant + embedding service (nomic-embed-text-v1.5) + agentdb-api REST
- [ ] MCP thin client — 5 outils (store, search, list, delete, debug), local-first
- [ ] Entries format + git integration — .agentdb/entries/ markdown source-of-truth
- [ ] Migration Supermemory → AgentDB

### Out of Scope

- Dépendances ruflo (claude-flow MCP, ruv-swarm, AgentDB ruflo) — trop lourd, breaking changes
- Répertoire agents/ séparé en YAML — duplication, source de stale
- Skill /dual-agent standalone — redondant avec pre-flight + ce:brainstorm
- Skill /codex-review standalone — même mécanique que SPARC Phase 5
- DDD tracking complet — la plupart des projets ont des domaines, pas besoin d'un système lourd
- DB locale SQLite — collègues ne partageraient pas la même mémoire

## Context

- Template Claude Code existant avec GSD, CARL, session-gate, pre-flight, execution-quality, hooks
- 8 gaps identifiés par comparaison avec ruflo : no micro-execution, single-perspective review, weak design validation, skipped pre-flight, bad semantic memory, implicit multi-agent conventions, lost ADRs, no DDD tracking
- VPS disponible pour Track B (Qdrant + embedding service déployables immédiatement)
- Chaque amélioration Track A est indépendante, zéro dépendance externe
- Milestone 1 Track A livrable sans VPS, Track B suit en Milestone 2

## Constraints

- **Budget lignes :** CLAUDE.md.template < 200 lignes, swarm-patterns.md < 80 lignes, SPARC SKILL.md < 150 lignes, execution-quality.md < 80 lignes au total
- **Zero deps Track A :** Aucune dépendance npm/gem externe pour les enrichissements template
- **Hooks exit 0 :** Tous les hooks doivent toujours exit 0 (ne jamais bloquer Claude)
- **Local-first AgentDB :** .agentdb/entries/ est la source de vérité git-tracked ; VPS = index rebuilable
- **CARL numbering :** Règles séquentielles — identifier le dernier numéro actif avant d'ajouter

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Milestones séparés Track A / Track B | Track A = zero deps, livrable indépendamment; VPS disponible mais infra à part | — Pending |
| swarm-patterns.md dans .claude/rules/ | Auto-chargé par tous les subagents, source unique pour rôles et topologie | — Pending |
| SPARC ne wrappe pas /gsd:execute-phase | Skill template indépendant, invoqué explicitement par l'utilisateur | — Pending |
| Enforcement pre-flight = CARL + session-gate | Défense en profondeur — CARL seul a été violé en production | — Pending |
| AgentDB remplace Supermemory (pas améliore) | Problème fondamental = boîte noire non débuggable | — Pending |
| VPS partagé (pas SQLite local) | Collègues voient la même mémoire en temps réel, rebuild possible | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-31 after initialization*
