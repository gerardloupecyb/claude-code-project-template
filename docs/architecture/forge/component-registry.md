---
title: "FORGE — Component Registry"
status: active
last_verified: 2026-04-14
owner: {{OWNER}}
phase: 24
slug: forge
---

# FORGE — Component Registry

> Inventaire vivant de tous les skills, hooks et leurs interdependances.
> Mettre a jour ce fichier dans le meme commit que tout ajout, retrait ou modification d'un skill ou hook.
> Ce fichier est l'index — le detail vit dans chaque SKILL.md et dans le code des hooks.

---

## 1. Skills — Inventaire

### Domain Architects (skill gate requis)

| Skill | Domaine | Gate marker | Trigger | Dependencies |
|---|---|---|---|---|
| `{{cloud_provider}}-{{identity_platform}}-architect` | {{CLOUD_PROVIDER}} / {{IDENTITY_PLATFORM}} / {{IDENTITY_PROVIDER}} / Graph | `.skill-locks/{{cloud_provider}}` | `.ps1`, `.psm1`, Graph, Exchange, Intune | `pre-tool-use.sh` enforce |
| `{{cloud_provider}}-infra-architect` | {{CLOUD_PROVIDER}} infra (Bicep, ARM, azd) | `.skill-locks/{{cloud_provider}}` | Bicep, ARM, Storage, Compute | `pre-tool-use.sh` enforce |
| `{{cloud_provider}}-ai-architect` | {{CLOUD_PROVIDER}} AI / Foundry | `.skill-locks/{{cloud_provider}}` | OpenAI, Foundry, AI Search, RAG | `pre-tool-use.sh` enforce |
| `{{WORKFLOW_ENGINE}}-workflow-architect` | {{WORKFLOW_ENGINE}} workflows | `.skill-locks/{{WORKFLOW_ENGINE}}` | `{{WORKFLOW_ENGINE}}/`, workflow JSON | `pre-tool-use.sh` enforce |
| `{{WORKFLOW_ENGINE}}-node-expert` | {{WORKFLOW_ENGINE}} node config | `.skill-locks/{{WORKFLOW_ENGINE}}` | IF/Switch, expressions | `pre-tool-use.sh` enforce |
| `{{WORKFLOW_ENGINE}}-code-nodes` | {{WORKFLOW_ENGINE}} Code nodes | `.skill-locks/{{WORKFLOW_ENGINE}}` | JS/Python dans Code nodes | `pre-tool-use.sh` enforce |
| `{{crm_platform}}-architect` | Go{{CRM_PLATFORM}} CRM | `.skill-locks/{{crm_platform}}` | {{CRM_PLATFORM}}, {{CRM_PLATFORM}}, {{CRM_PLATFORM}} | `pre-tool-use.sh` enforce |
| `{{project}}-{{scripting_lang}}-script-writer` | {{SCRIPTING_LANG}} scripts | `.skill-locks/{{cloud_provider}}` | `.ps1`, `.psm1` (combine avec {{cloud_provider}}) | `pre-tool-use.sh` enforce |

### Security & Governance

| Skill | Role | Trigger | Gate mecanique |
|---|---|---|---|
| `supply-chain-audit` | Audit SCAG avant install dep externe | `/supply-chain-audit` | `pre-tool-use.sh` SCAG gate (bloque install verbs) |
| `security-audit` | AgentShield — scan securite de la config `.claude/` (PAS un SAST du code) | `/security-audit` | Propose si diff touche `.claude/` ; obligatoire avant `/promote` |
| `pre-flight` | Review multi-agent des plans AVANT execution | `/pre-flight` | Aucun — advisory |
| `{{project}}-pre-flight` | Wrapper project-local du skill template-synced `pre-flight` ; invoque l'upstream pour le verdict puis ajoute (strict append-only) l'autonomy-readiness advisory (declarative oracle schema, Path B ; moteur `scripts/autonomy-advisory/`) | `/{{project}}-pre-flight` | Aucun — advisory append-only ; kill switch operateur `.planning/config.json` |
| `session-gate` | Validation mecanique de l'etat de session | Auto (session boundaries) | Aucun — validation |
| `copilot-checklist-gate` | Checklist gate pour Codex seulement | Avant operations Codex | Aucun — gate soft |

### Workflow & Orchestration

| Skill | Role | Trigger | Integration hooks |
|---|---|---|---|
| `prepare-phase` | Orchestration complete preparation de phase | `/prepare-phase` | Appelle `architecture-kit`, `document-review` ; **Step 6 route vers `/{{project}}-pre-flight`** (W1 per D-10, ex-`/pre-flight`) ; Steps 3+4 fan-out sur 4 agents parallèles (arch + doc-review + Codex adversarial + Gemini adversarial) avec cross-model consensus |
| `execute-phase-auto` | Orchestration exécution autonome de phase (twin de prepare-phase) | `/execute-phase-auto {N}`, `--autonomous` | Wrapper-only — gate check → danger classification one-way → `/gsd:execute-phase` → multi-agent validation → verdict ; Step-3 fix loop = atomic-iteration state machine bornée par run-budget `max_fix_iterations` (halt-only, cross-vendor GO 2026-06-04) ; danger hard-stops + Fix Escalation Gate ; ne ferme pas (propose `/close-phase`) |
| `close-phase` | Orchestration closure protocol post-execution (verify-work, conditional {{project}}:review soft gate, SUMMARY, MEMORY, architecture artefact reconciliation, todo stale, multi-select lesson/brainstorm-archival/commit-push, folder migration active→complete) | `/close-phase {N}`, `--partial`, `--skip-review`, `--dry-run` | Wrapper-only — invoque `/gsd:verify-work`, `/{{project}}:review`, `/architecture-kit --update`, `/lesson`, `/todo stale`, `/commit-push` ; pas de hook d'enforcement (Phase B déferrée) |
| `architecture-kit` | Generer/maj artefacts architecture | `/architecture-kit` | Step 6: graphify sync |
| `sparc` | Micro-execution structuree (Spec/Pseudo/Arch/Refine/Complete) | `/sparc` | Aucun |
| `task-router` | Route taches vers modele appropriate | `/task-router` | Aucun |
| `promote` | Promotion dev → prod ({{WORKFLOW_ENGINE}} + runbooks AA split publish/verify + {{SCRIPTING_LANG}} stub + migrations {{HOSTING_VENDOR}} staging→prod) | `/promote` | `pre-mcp-gate.sh`, `pre-tool-use.sh` ({{cloud_provider}} skill gate pour runbooks) |
| `commit-push` | Commit + push main | `/commit-push` | Post-commit hooks |
| `todo` | CRUD `.planning/todos/` | `/todo` | Aucun |
| `plan-ceo-review` | Review CEO/founder des plans | `/plan-ceo-review` | Aucun |
| `office-hours` | Interrogation produit YC-style | `/office-hours` | Aucun |
| `pmo` | Portfolio pulse read-only — drift, collisions, stagnation, active phases (déterministe, pas de LLM) | `/pmo`, `/pmo --statusline` | SessionStart hook opt-in (documenté dans SKILL.md, non wiré par défaut) |

### Knowledge & Memory

| Skill | Role | Trigger | Integration hooks |
|---|---|---|---|
| `knowledge-sync` | Sync docs → {{RAG_BACKEND}} | `/knowledge-sync` | `post-commit` hook, `session-start.sh` |
| `knowledge-grounding` | Query routing {{RAG_BACKEND}} (v1.1 — documente le scope indexé par collection + trous structurels routés vers Grep via `tool-routing.md § Scope-Based Routing`) | Automatique (claims architecture) | Aucun |
| `graphify` | Knowledge graph (AST + structural + semantic) | `/graphify` | `post-commit`, `session-start.sh` (watch), architecture-kit Step 6 |
| `lesson` | Capture lecon dans LESSONS.md + supersession declarative (flag `--supersedes <slug>` insere marker `_Superseded by:_` dans lecon cible ; Etape 2.5 collision check deterministe via `compute_slug`). Integration avec `scripts/knowledge-sync.py § parse_lessons_md` pour archive {{RAG_BACKEND}} des lecons superseded (metadata kind=lesson + superseded_by). | `/lesson`, `/lesson --supersedes <slug>` | `pre-tool-use.sh` (lessons auto-surfacing) |
| `memory-consolidate` | Audit coherence cross-fichiers memoire | `/memory-consolidate` | Aucun |
| `context-checkpoint` | Sauvegarde rapide avant coupure session | `/context-checkpoint` | Aucun |
| `context-manager` | Regles gestion contexte et chain of thought | Automatique | Aucun |

### Review & Quality

| Skill | Role | Trigger |
|---|---|---|
| `{{project}}-review` | Code review {{PROJECT}} (ce:review + architecture + security + cross-vendor consensus + Step 8 deterministic SAST `sast-scanner` + merge-readiness verdict) | `/{{project}}-review` |
| `{{project}}-code-reviewer` | Cross-stack reviewer (PS, {{WORKFLOW_ENGINE}}, {{CRM_PLATFORM}}) | Automatique (review) |
| `gemini-review` | Review adversarial via Gemini CLI | `/gemini-review` |
| `reference-audit` | Validation docs/references/ | `/reference-audit` |
| `rules-distill` | Distille LESSONS.md en CARL rules | `/rules-distill` |
| `code-xray` | Exploration token-efficient par symboles | `/code-xray` |

### Compliance & Documentation

| Skill | Role | Trigger |
|---|---|---|
| `data-compliance-advisor` | Audit {{COMPLIANCE_FRAMEWORK_PRIMARY}} / {{COMPLIANCE_FRAMEWORK_FEDERAL}} / {{COMPLIANCE_FRAMEWORK_HEALTH}} avant design | Avant architecture touchant PI |
| `infosec-governance-writer` | Redaction docs gouvernance infosec | `/infosec-governance-writer` |
| `client-email-template-writer` | Templates emails bilingues clients | `/client-email-template-writer` |

### Tools & Utilities

| Skill | Role | Trigger |
|---|---|---|
| `excalidraw-diagram` | Generer diagrammes Excalidraw JSON | `/excalidraw-diagram` |
| `skill-refresh` | Refresh skills quand platform updates | `/skill-refresh` |
| `skill-forge` | Creer un skill complet (SKILL.md + references/ + tests/) respectant le framework, valide structurellement (19 checks) et comportementalement (subagent par cas), itere max 3 rounds. Framework canonique : `.claude/rules/skill-framework.md` | `/skill-forge "brief"`, `/skill-forge --brief` |
| `template-sync` | Sync avec project-template-collab | `/template-sync` |
| `project-sync` | Sync etat projet avec Linear/GSD | `/project-sync` |
| `project-bootstrap` | Bootstrap nouveau projet | `/project-bootstrap` |

---

## 2. Hooks — Inventaire

### Claude Code Hooks (`.claude/hooks/`)

| Hook | Fichier | Trigger | Bloquant | Role |
|---|---|---|---|---|
| **session-start** | `session-start.sh` | SessionStart (startup + compact) | Non | {{RAG_BACKEND}} auto-start, staleness check, auto-sync, graphify watch launch, upstream drift auto-resolve (trusted + capped), stale todos, phase context, MEMORY.md injection |
| **pre-tool-use** | `pre-tool-use.sh` | PreToolUse (Write/Edit/MultiEdit/Bash) | **Oui** | Skill gate ({{cloud_provider}}/{{WORKFLOW_ENGINE}}/{{crm_platform}} markers) + SCAG gate (install verbs) + lessons auto-surfacing |
| **pre-mcp-gate** | `pre-mcp-gate.sh` | PreToolUse (MCP mutations) | **Oui** | Bloque mutations MCP prod ({{WORKFLOW_ENGINE}}-mcp, prod-{{crm_platform}}-mcp, prod-{{crm_platform}}-care-mcp) |
| **post-knowledge-sync** | `post-knowledge-sync.sh` | PostToolUse (Write/Edit/MultiEdit) | Non | Queue `.sync-queue`, nudge consolidate apres 10s idle |
| **pre-compact** | `pre-compact.sh` | Avant compaction contexte | Non | Sauvegarde etat volatile |
| **pre-agent** | `pre-agent.sh` | Avant spawn subagent | Non | Injection contexte ({{RAG_BACKEND}} collections, CARL) |
| **memory-retention** | `memory-retention.sh` | Fin de session (guidance) | Non | Rappel mise a jour MEMORY.md |
| **codex-done-checklist** | `codex-done-checklist.sh` | UserPromptSubmit | Non | Injecte la checklist `verification-discipline.md` § "Codex done {id} valide" quand le prompt signale une completion Codex (todo 109 / M1) |
| **kv-secret-rule8-nudge** | `kv-secret-rule8-nudge.sh` | PostToolUse (Bash) | Non | Detecte `az keyvault secret set/delete` + cert import ; injecte un rappel {{PROJECT}}TECH_RULE_8 (update services-and-access.md same-commit) — ferme le gap KV-via-CLI sans git footprint |

### Git Hooks (`.githooks/`)

| Hook | Fichier | Trigger | Bloquant | Role |
|---|---|---|---|---|
| **pre-commit** | `.githooks/pre-commit` | `git commit` | **Oui** (partiel) | CLAUDE.md budget 50 lignes, gitleaks SAST, PSScriptAnalyzer, co-presence MCP/infra (soft) |
| **post-commit** | `.githooks/post-commit` | Apres `git commit` | Non | {{RAG_BACKEND}} auto-sync (knowledge-sync.py) + graphify rebuild (AST code + structural docs) |

---

## 3. Interdependances

### Chaines de dependance

```
session-start.sh
  ├── {{RAG_BACKEND}} Docker compose up
  ├── knowledge-sync.py (incremental)
  ├── graphify.watch (launch background)
  ├── upstream drift auto-resolve
  └── stale todo check

pre-tool-use.sh
  ├── skill gate → .skill-locks/{domain}
  ├── SCAG gate → .skill-locks/scag-approved
  └── lessons auto-surfacing → LESSONS.md grep

post-commit (git)
  ├── knowledge-sync.py ({{RAG_BACKEND}} incremental)
  └── graphify rebuild (AST + structural docs)

/architecture-kit
  ├── /excalidraw-diagram (Step 5, si disponible)
  ├── graphify sync (Step 6)
  └── LIVE-ARCHITECTURE.md update (Step 6)

/prepare-phase
  ├── /architecture-kit (create mode)         [Agent A — parallel]
  ├── /document-review                        [Agent B — parallel]
  ├── codex adversarial review of PLAN.md     [Agent C — parallel, skip if CLI absent]
  ├── gemini adversarial review of PLAN.md    [Agent D — parallel, skip if CLI/API key absent]
  │     └── cross-model consensus (C × D) if both ran
  └── /pre-flight                             [sequential, after A-D complete]

/supply-chain-audit
  └── .skill-locks/scag-approved (Step 5a) → pre-tool-use.sh SCAG gate
```

### Matrice skills × hooks

| Skill | pre-tool-use | pre-mcp-gate | post-commit | session-start |
|---|---|---|---|---|
| Domain architects ({{cloud_provider}}/{{WORKFLOW_ENGINE}}/{{crm_platform}}) | Gate enforce | — | — | — |
| supply-chain-audit | Produit scag-approved | — | — | — |
| knowledge-sync | — | — | Auto-sync | Auto-sync |
| graphify | — | — | AST + structural rebuild | Watch launch |
| lesson | Lessons auto-surfacing | — | — | — |
| promote | {{WORKFLOW_ENGINE}}-mcp prod mutation guard + runbook {{CLOUD_PROVIDER}} skill-gate | Gate enforce | — | — |
| commit-push | — | — | Triggers post-commit | — |

---

## 4. Regles de maintenance

### Quand mettre a jour ce fichier

- Ajout ou retrait d'un skill → mettre a jour la table du groupe concerne
- Ajout ou retrait d'un hook → mettre a jour la table hooks + interdependances
- Modification d'une interdependance (skill X depend maintenant de hook Y) → mettre a jour la matrice
- Renommage d'un skill ou hook → mettre a jour toutes les references

### Co-updates obligatoires

| Changement | Ce fichier | Aussi mettre a jour |
|---|---|---|
| Nouveau skill | Ajouter dans le groupe | `.claude/integrations.md` si MCP, `governance.md` si gate |
| Nouveau hook | Ajouter dans hooks | `security-architecture.md` hooks table, `governance.md` enforcement |
| Nouvelle interdependance | Ajouter dans matrice | `operating-model.md` si impact workflow |
| Skill retire | Retirer de la table | `.claude/integrations.md`, supprimer le dossier skill |

---

## 5. Classification — Provenance et reutilisabilite

### Provenance des skills

| Origine | Description | Exemples | Mise a jour |
|---|---|---|---|
| **Template** | Vient de `project-template-collab`, generique, reutilisable tel quel | `sparc`, `pre-flight`, `architecture-kit`, `excalidraw-diagram`, `commit-push`, `todo`, `lesson`, `knowledge-sync`, `context-manager` | `/template-sync` ou `/skill-refresh` |
| **{{PROJECT}}-specific** | Cree pour {{PROJECT}}, non reutilisable sans adaptation | `{{project}}-review`, `{{project}}-code-reviewer`, `{{project}}-{{scripting_lang}}-script-writer`, `session-gate`, `copilot-checklist-gate`, `promote` | Manuel |
| **{{PROJECT}}-adaptable** | Cree pour {{PROJECT}} mais le pattern est generique — reutilisable en adaptant le contenu | `supply-chain-audit`, `client-email-template-writer`, `infosec-governance-writer`, `data-compliance-advisor`, `reference-audit`, `pmo` (FORGE-portable via `config.yaml` — Phase 1005) | Manuel + extraire le pattern dans FORGE |
| **Externe** | Package tiers installe via MCP-only pattern | `graphify` | `uv tool upgrade graphifyy` + recopy SKILL.md |
| **Compound Engineering** | Vient du framework CE (compound-engineering) | `ce-review`, `ce-plan`, `ce-brainstorm`, `ce-work`, `agent-browser`, `brainstorming`, `document-review` | Via compound-engineering updates |
| **GSD** | Vient du framework GSD (get-shit-done) | Tous les `gsd:*` commands | TBD — retarget vers open-gsd 1.4.5 **audité** en Phase 22.1 (DEC-053) ; ne PAS `/gsd:update` vers une version non auditée |
| **CARL** | Vient du framework CARL | `carl:manager`, `carl:tasks:*` | CARL framework updates |

### Processus de mise a jour par origine

#### Template skills (`/template-sync`)

```
1. /template-sync
   → compare skills du projet vs project-template-collab
   → affiche les ecarts (ajouts, modifications, suppressions)
   → propose les mises a jour

2. Pour chaque skill modifie :
   - Diff entre version locale et version template
   - Si customise localement : merge manuel (ne pas ecraser les customisations)
   - Si non customise : remplacement direct

3. /skill-refresh {skill-name}
   → refresh un skill specifique depuis le template
```

#### {{PROJECT}}-specific skills (manuel)

```
1. Identifier le besoin de modification (nouveau domain, nouvelle regle)
2. Editer le SKILL.md directement
3. Si le skill a un hook dependant → verifier la coherence
4. Mettre a jour ce registre (component-registry.md)
5. Commit dans le meme commit que le changement fonctionnel
```

#### Externe (graphify, futurs packages)

```
1. Verifier la nouvelle version : uv tool list | grep {pkg}
2. Upgrade : uv tool install '{pkg}=={new-version}' --reinstall
3. Recopier le SKILL.md mis a jour :
   cp ~/.local/share/uv/tools/{pkg}/lib/python*/site-packages/{pkg}/skill.md \
      .claude/skills/{name}/SKILL.md
4. Si bump majeur → re-trigger /supply-chain-audit (SCAG condition)
5. Mettre a jour ce registre + integrations.md
```

#### Compound Engineering / GSD / CARL

```
CE : mises a jour via le framework compound-engineering (repo source)
GSD : provenance TBD — retarget vers open-gsd 1.4.5 audité en Phase 22.1 (DEC-053) ;
      ne PAS propager /gsd:update / /gsd:reapply-patches vers une version non auditée
      (le cutover 1.4.5 a falsifié la prémisse de compatibilité layout — cf. Phase 36)
CARL : mises a jour via le manifest .carl/ (pas de mecanisme auto)
```

### Documentation detaillee (sources canoniques)

| Sujet | Document canonique | Ce qu'il couvre |
|---|---|---|
| **Cycle de vie complet** | `docs/solutions/agents/skill-lifecycle.md` | Anatomie 5 sections, creation 7 etapes, refresh automatise ({{WORKFLOW_ENGINE}} release monitor), retraite, adaptation autres stacks |
| **Inventaire detaille** | `docs/solutions/agents/skills-inventory.md` | 40 skills en 8 groupes, triggers, MCP dependances, skill-gate requis, position workflow |
| **Skill refresh autonome** | `.claude/skills/skill-refresh/SKILL.md` | Process 7 steps : detect → fetch docs → extract claims → identify gaps → apply fixes → summary → commit |
| **Release monitoring** | `scripts/upstream-watch/` + `/upstream-sync` | Drift detection sur sources upstream (changelogs, lois, frameworks). Phase 1002 ({{WORKFLOW_ENGINE}} workflows) CANCELLED — superseded par upstream-watcher (Phase 24.2). Quand drift detecte → todo auto → `/skill-refresh` |
| **Compliance skill** | `.claude/skills/data-compliance-advisor/` | Sources upstream dans `docs/references/frameworks/` ({{COMPLIANCE_FRAMEWORK_PRIMARY}}, {{COMPLIANCE_FRAMEWORK_FEDERAL}}, {{COMPLIANCE_FRAMEWORK_HEALTH}}) — surveilles par `upstream-source-watcher` (Phase 24.2). Drift detecte → `/skill-refresh` ou mise a jour manuelle |

**Ce registre** (component-registry.md) est l'**index d'acces rapide** — les documents ci-dessus contiennent le detail. Ne pas dupliquer le contenu ici.

### Extraction de patterns {{PROJECT}} → FORGE

Quand un skill "{{PROJECT}}-adaptable" est suffisamment mature :

1. Identifier le pattern generique sous-jacent (ex: `supply-chain-audit` → triad pattern + install gate pattern)
2. Documenter dans `docs/architecture/forge/{pattern-name}.md`
3. Le skill reste {{PROJECT}}-specific ; le pattern FORGE est reutilisable
4. Cross-referencer : SKILL.md pointe vers le FORGE pattern, le pattern pointe vers l'implementation {{PROJECT}}

---

*Module: FORGE meta-system*
*Generated: 2026-04-12*
