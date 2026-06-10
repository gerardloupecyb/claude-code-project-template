---
title: "FORGE — Solution Architecture"
status: active
last_verified: 2026-04-08
owner: {{OWNER}}
phase: 24
slug: forge
---

# FORGE — Solution Architecture

## 1. Contexte et motivation

FORGE — Framework for Governed Agentic Operations Engineering — est le meta-systeme qui gouverne la facon dont Claude Code opere sur le projet {{PROJECT}}. Il ne produit pas de features metier : il produit la capacite a les produire de facon sure, reproductible et sans dette.

**Probleme resolu :** Un operateur solo + Claude Code sans cadre de gouvernance = autonomie dangereuse. Les agents hallucinent des patterns, ignorent les contraintes de securite, dualisent les decisions, et laissent des artefacts incoherents. FORGE impose un cadre sans sacrifier la velocite.

**Contexte operationnel :** {{PROJECT}} est un {{BUSINESS_MODEL}} premium (solo-operateur). Chaque session Claude Code produit du code de production, des workflows {{WORKFLOW_ENGINE}}, des scripts {{SCRIPTING_LANG}} {{IDENTITY_PLATFORM}}, ou des decisions d'architecture. L'absence de gouvernance a un cout direct : incidents de securite, bugs en production, dette architecturale, perte de contexte entre sessions.

**Solution precedente :** Ensemble de fichiers CLAUDE.md + rules/ non coordonnes, sans enforcement mecanique, sans trace des decisions, sans grounding factuel. Taux d'erreur elevee sur les domaines proteges ({{CLOUD_PROVIDER}}, {{WORKFLOW_ENGINE}}, {{CRM_PLATFORM}}).

## 2. Scope

| In Scope | Out of Scope |
|----------|-------------|
| Phase 24 : documentation {{PROJECT}}-specifique (vrais MCPs, vrais domaines, vraies regles) | Phase 22 : extraction generique vers repo `forge-template` |
| 5 artefacts arch-kit dans `docs/architecture/forge/` | Placeholders stack-agnostiques |
| 8 solution docs dans `docs/solutions/agents/` | Traduction EN des labels de diagrammes |
| 15 MCP servers inventories dans `.claude/integrations.md` | Deploiement cloud ou multi-utilisateur |
| 41 skills dans `.claude/skills/` | Repos FORGE pour d'autres projets |
| 7 hooks dans `.claude/hooks/` | Mecanisme de templateisation des docs de gouvernance |
| Rules CARL {{PROJECT}} (`.carl/{{project}}tech`) | Extraction automatique FORGE vers stack tierce |

## 3. Les 4 piliers FORGE

| Pilier | Definition | Composants principaux | Fichiers canoniques |
|--------|-----------|----------------------|---------------------|
| **Governed** | Toute action agent est filtrée par un mécanisme d'enforcement avant exécution | 7 hooks (`session-start`, `pre-tool-use`, `pre-mcp-gate`, `post-tool-use`, `session-gate`, `pre-commit`, indexation), skill-gate (domaines {{cloud_provider}}/{{WORKFLOW_ENGINE}}/{{crm_platform}}), rules CARL {{PROJECT}}, guards pre-commit (gitleaks, Semgrep, PSScriptAnalyzer) | `governance.md`, `skill-gate.md`, `pre-tool-use.sh`, `pre-mcp-gate.sh`, `.githooks/pre-commit` |
| **Agentic** | Claude Code est l'orchestrateur ; subagents, MCPs et modeles externes sont les executors | Claude Code orchestrator, subagents (swarm-patterns, 4+1 pre-flight agents), 15 MCP servers, delegation multi-modele (Codex CLI, OpenRouter, Gemini CLI), {{RAG_BACKEND}} grounding | `swarm-patterns.md`, `router-rules.md`, `cognitive-patterns.md`, `.claude/integrations.md` |
| **Operations** | La session a un cycle de vie formalise avec closure obligatoire et memoire hygienique | Lifecycle session (start→closure), 8 etapes de closure, 6 layers memoire (LESSONS/DECISIONS/STATE/MEMORY/AgentDB/docs/CARL), knowledge-sync {{RAG_BACKEND}}, MEMORY hygiene (cap 8 sessions, archive) | `workflow-guide.md`, `memory/MEMORY.md`, `LESSONS.md`, `DECISIONS.md`, `.planning/STATE.md` |
| **Engineering** | Chaque phase suit un flow structure avec gates mecaniques avant et apres execution | GSD phases (discuss→plan→checker→pre-flight→execute→secure→verify→closure), TDD plans, architecture-kit (5 artefacts par solution), pre-flight (4+1 agents), plan-checker (marker obligatoire) | `workflow-architecture.md`, `.claude/skills/architecture-kit/SKILL.md`, `.claude/skills/pre-flight/SKILL.md`, `.planning/phases/` |

## 4. Positionnement

| Dimension | FORGE (ce projet) | Scaffold basique | SDLC standard |
|-----------|-------------------|-----------------|---------------|
| **Audience** | Operateur solo + Claude Code | Dev humain + templates | Equipe + CI/CD pipeline |
| **Enforcement** | Mecanique (hooks bloquants) | Documentaire (conventions) | Outillage CI (lint, tests) |
| **Memoire** | 6 layers (cache chaud, decisions, state, session, semantique, patterns) | README + changelog | Wiki + tickets Jira |
| **Autonomie agent** | Gouvernee (skill-gate, CARL, MCP gate) | Non deleguee | Partielle (copilot, revues) |
| **Grounding factuel** | {{RAG_BACKEND}} local (requetes < 100ms) | Aucun | Documentation statique |
| **Multi-modele** | Delegue selon type de tache (Codex/Gemini/OpenRouter) | Modele unique | Pipeline CI (lint, SAST) |
| **Capitalisation** | Flywheel (/ce:compound → CARL → AgentDB) | Ad hoc | Knowledge base manuelle |
| **Scope** | Meta-systeme (gouverne les agents) | Template de projet | Workflow humain |

**Ce que FORGE ajoute** : la gouvernance de l'autonomie agentique. Il ne remplace pas Jira, GitFlow ou CI/CD — il ajoute la couche de controle necessaire quand l'agent est l'operateur principal.

## 5. Decisions architecturales

| Decision | Choix | Raison |
|----------|-------|--------|
| Local-first | Aucun service cloud pour les outils FORGE ({{RAG_BACKEND}} local, hooks locaux, CARL local) | {{COMPLIANCE_FRAMEWORK_PRIMARY}}, zero latence, pas de dependance externe pour les outils de gouvernance |
| MCP-natif | Integration via MCP servers (pas d'API custom) | Integration native Claude Code, pas de code d'adaptation, 15 servers couvrent tous les domaines |
| Markers session-scoped | Skill-gate markers `.skill-locks/{domain}` recrees a chaque session (gitignored) | Pas d'etat persistent entre sessions — chaque session valide explicitement ses domaines |
| Hierarchie memoire 6 couches | LESSONS (cache chaud, cap 50) → DECISIONS (actives, cap 25) → STATE (GSD, auto) → MEMORY (session) → AgentDB (semantique VPS) → docs/solutions (patterns git) | Chaque couche repond a un besoin distinct : vitesse, durabilite, semantique, patterns |
| Documentation FR | Arch-kit docs en FR, solution docs en FR (D-01/D-02/D-03 contexte) | Standard etabli pour le projet {{PROJECT}}. Phase 22 gere la traduction EN pour le template generique |
| Enforcement par hooks, pas par policy | pre-tool-use.sh bloque les Write/Edit sur domaines proteges avant execution | Un document de policy n'empeche pas une action ; un hook bloquant si |
| {{RAG_BACKEND}} pour grounding (pas NotebookLM) | {{RAG_BACKEND}} Docker local via MCP chroma-mcp | NotebookLM : pas d'API, pas d'integration MCP, pas de controle local. {{RAG_BACKEND}} : queries < 100ms, 100% local, {{COMPLIANCE_FRAMEWORK_PRIMARY}} |
| GSD comme macro-orchestrateur | GSD gere roadmap, phases, milestones, state | Structure reproductible pour les 24+ phases du projet — pas d'improvisation ad hoc |

## 6. Composants principaux — 13 artefacts Phase 24

Phase 24 produit 13 artefacts en 5 plans. Les 5 premiers sont des artefacts arch-kit dans `docs/architecture/forge/`. Les 8 suivants sont des solution docs dans `docs/solutions/agents/`.

### Arch-kit docs (format canonique {{RAG_BACKEND}})

| Plan | Artefact | Description |
|------|---------|-------------|
| 24-01 | `docs/architecture/forge/solution-architecture.md` | Vue d'ensemble FORGE : 4 piliers, scope, decisions, positionnement (ce document) |
| 24-02 | `docs/architecture/forge/logical-architecture.md` | Layers MACRO/MICRO/NANO, composants, stack memoire (6 couches), contrat filesystem |
| 24-02 | `docs/architecture/forge/security-architecture.md` | Pipeline de gouvernance (hooks → skill-gate → CARL → pre-commit), threat model |
| 24-02 | `docs/architecture/forge/integration-architecture.md` | Topologie MCP (15 servers groupes par domaine), dependances externes |
| 24-03 | `docs/architecture/forge/operating-model.md` | Cycle de vie session, 8 etapes closure, hygiene memoire, maintenance |

### Solution docs (format enrichi D-14)

| Plan | Artefact | Description |
|------|---------|-------------|
| 24-03 | `docs/solutions/agents/memory-layer-hierarchy.md` | 6 couches memoire : quand utiliser, comment alimenter, limites et caps |
| 24-03 | `docs/solutions/agents/governance-enforcement-pipeline.md` | 4 couches enforcement : rules, CARL, skill-gate, hooks, pre-commit |
| 24-04 | `docs/solutions/agents/multi-model-delegation.md` | Routing modele (Opus/Sonnet/Codex/Gemini), handoff protocol, retry/escalation |
| 24-04 | `docs/solutions/agents/skill-gate-pattern.md` | Domaines proteges, markers, correspondance hooks, ajout de domaine |
| 24-04 | `docs/solutions/agents/skill-lifecycle.md` | Anatomie d'un skill, categories, creation, rafraichissement, alertes |
| 24-05 | `docs/solutions/agents/gsd-phase-workflow-pattern.md` | Flow complet phase GSD : discuss → plan → checker → pre-flight → execute → closure |
| 24-05 | `docs/solutions/agents/{{rag_backend}}-grounding-pattern.md` | Query templates, rationalization table, collections, when-to-query |
| 24-05 | `docs/solutions/agents/skills-inventory.md` | Registre de tous les skills (41) : nom, trigger, domaine, MCP, skill-gate |

---
*Phase: 24-forge-architecture-documentation*
*Generated: 2026-04-08*
