---
title: "FORGE — Maturity Model"
status: active
last_verified: 2026-04-12
owner: {{OWNER}}
phase: 24
slug: forge
---

# FORGE — Maturity Model

> Quels composants FORGE sont obligatoires vs optionnels.
> Un projet simple n'a pas besoin de 44 skills. Ce modele definit 3 tiers progressifs.

---

## Tier 1 — Foundation (obligatoire, ~2h setup)

Le minimum viable pour qu'un projet beneficie de FORGE. Sans ces composants, FORGE n'apporte pas de valeur.

| Composant | Fichiers | Role |
|---|---|---|
| **CLAUDE.md bootstrap** | `CLAUDE.md` (< 50 lignes) | Point d'entree, pointeurs |
| **Governance rules** | `governance.md`, `verification-discipline.md`, `cognitive-patterns.md` | Discipline de base |
| **Memory layer** | `memory/MEMORY.md`, `LESSONS.md`, `DECISIONS.md` | Persistance cross-session |
| **Session hooks** | `session-start.sh`, `memory-retention.sh` | Injection memoire auto |
| **Closure protocol** | `workflow-guide.md` | Loop closure obligatoire |
| **Tool routing** | `tool-routing.md` | Prevention context flooding |
| **Todo discipline** | `todo-discipline.md`, `todo/` skill | Tracking taches structure |
| **Commit-push** | `commit-push/` skill | Solo-dev workflow |
| **Lesson capture** | `lesson/` skill | Compound learning |

**Resultat** : sessions coherentes, memoire qui persiste, context flooding prevenu, loop closure systematique.

---

## Tier 2 — Governance (recommande, +4h setup)

Ajoute les gates mecaniques et la verification automatisee. Recommande des que le projet a > 10 fichiers ou touche des domaines sensibles.

| Composant | Fichiers | Role |
|---|---|---|
| **Skill gate** | `skill-gate.md`, `pre-tool-use.sh` | Protection domaines sensibles |
| **MCP gate** | `pre-mcp-gate.sh` | Protection mutations prod |
| **SCAG** | `supply-chain-audit.md`, `supply-chain-audit/` skill, `pre-tool-use.sh` SCAG block | Gate install deps externes |
| **DSW** | `dependency-surveillance.md`, `.github/dependabot.yml`, `.github/workflows/osv-scan.yml` | CVE monitoring continu |
| **Pre-commit guards** | `.githooks/pre-commit` | CLAUDE.md budget, gitleaks, co-presence |
| **CARL rules** | `.carl/{domain}` | Guidance comportementale |
| **Architecture-kit** | `architecture-kit/` skill | Arch docs standardises |
| **Pre-flight** | `pre-flight/` skill | Review multi-agent pre-execution |
| **SPARC** | `sparc/` skill | Micro-execution structuree |
| **Prepare-phase** | `prepare-phase/` skill | Orchestration phase complete |

**Resultat** : gates mecaniques empechent les erreurs, supply chain securise, architecture documentee, review automatisee.

---

## Tier 3 — Intelligence (optionnel, +4h setup)

Ajoute la couche de connaissance semantique et les outils avances. Pour les projets complexes (> 50 fichiers, > 5 domaines, cross-session context critique).

| Composant | Fichiers | Role |
|---|---|---|
| **{{RAG_BACKEND}}** | `docker-compose.{{rag_backend}}.yml`, `knowledge-sync.py`, `knowledge-sync/` skill, `knowledge-grounding/` skill | RAG local semantique |
| **Graphify** | `graphify/` skill, post-commit rebuild, watch, MCP server | Knowledge graph AST + structural |
| **Swarm patterns** | `swarm-patterns.md` | Multi-agent coordination |
| **Router rules** | `router-rules.md` | Model routing multi-executor |
| **Task router** | `task-router/` skill | Handoff vers executors externes |
| **Gemini review** | `gemini-review/` skill | Cross-AI adversarial review |
| **Context manager** | `context-manager/` skill | Chain of thought discipline |
| **Code xray** | `code-xray/` skill | Token-efficient codebase exploration |

**Resultat** : knowledge grounding previent les hallucinations, graph persistant reduit les tokens, multi-model routing optimise cout/qualite.

---

## Tier 4 — Domain (project-specific, effort variable)

Skills et configurations specifiques au domaine technique du projet. Non inclus dans le template — cree par le projet.

| Composant | Exemple {{PROJECT}} | Ce que le projet cree |
|---|---|---|
| Domain architect skills | {{cloud_provider}}-{{identity_platform}}-architect, {{WORKFLOW_ENGINE}}-*, {{crm_platform}}-* | Skills pour le stack du projet (aws, rails, k8s...) |
| Domain CARL rules | RULE_10 {{SECRETS_MANAGER}}, RULE_14 Docker, RULE_15 {{WORKFLOW_ENGINE}} | Rules metier du projet |
| Compliance advisor | data-compliance-advisor ({{COMPLIANCE_FRAMEWORK_PRIMARY}}, {{COMPLIANCE_FRAMEWORK_FEDERAL}}) | Advisor juridiction du projet |
| Writer skills | {{project}}-{{scripting_lang}}-script-writer | Writer pour le langage principal |
| Promote pipeline | promote/ skill ({{WORKFLOW_ENGINE}} dev→prod) | Pipeline promotion du projet |

---

## Matrice de decision

| Le projet... | Tier recommande |
|---|---|
| Est un nouveau side-project (< 10 fichiers) | Tier 1 |
| A des domaines sensibles (prod, API keys, auth) | Tier 2 |
| A > 50 fichiers et des sessions longues | Tier 3 |
| A un stack technique specifique ({{CLOUD_PROVIDER}}, {{WORKFLOW_ENGINE}}, {{CRM_PLATFORM}}...) | Tier 4 (domain skills) |

Les tiers sont **additifs** : Tier 2 inclut Tier 1, Tier 3 inclut Tier 2, Tier 4 ajoute par-dessus.

---

## Metriques par tier

| Tier | Setup | Maintenance | Token overhead/session | Valeur principale |
|---|---|---|---|---|
| 1 Foundation | ~2h | ~0 (auto) | ~2K (rules injection) | Coherence cross-session |
| 2 Governance | +4h | ~5min/semaine (CVE triage) | +3K (gates + CARL) | Prevention erreurs |
| 3 Intelligence | +4h | ~0 (auto-sync) | +2K (grounding queries) | Token reduction 100x sur queries |
| 4 Domain | Variable | Variable | Variable | Expertise domaine encodee |
