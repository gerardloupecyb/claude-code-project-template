# Skill Gate

> Source canonique du skill gate pour {{PROJECT}}.
> Ce fichier définit quels skills doivent être chargés avant toute implémentation dans un domaine protégé, ainsi que le marker `.skill-locks/{domain}` attendu par le hook.
> `CLAUDE.md` doit seulement pointer vers ce fichier, pas recopier son contenu.

## Règle générale

Avant d'écrire, éditer ou configurer dans un domaine protégé :

1. Identifier le domaine de la tâche
2. Charger le skill requis
3. Créer le marker `.skill-locks/{domain}`
4. Procéder seulement après le marker

Les markers sont session-scoped et gitignored. Ils doivent être recréés à chaque session.

## Domain Routing

| Domaine | Triggers | Skills requis | Marker |
|---|---|---|---|
| {{CLOUD_PROVIDER}} / {{IDENTITY_PLATFORM}} / {{IDENTITY_PROVIDER}} / Graph / {{SCRIPTING_LANG}} | `.ps1`, `.psm1`, `.psd1`, `scripts/`, Graph, Exchange, Intune, {{IDENTITY_PROVIDER}}, {{IDENTITY_PLATFORM}} | `{{cloud_provider}}-{{identity_platform}}-architect` + `{{project}}-{{scripting_lang}}-script-writer` si script/module {{SCRIPTING_LANG}} | `mkdir -p .skill-locks && touch .skill-locks/{{cloud_provider}}` |
| {{CLOUD_PROVIDER}} infra | Bicep, ARM, `azd`, Storage, Compute, quotas, diagnostics, cost, deploy | `{{cloud_provider}}-infra-architect` | `mkdir -p .skill-locks && touch .skill-locks/{{cloud_provider}}` |
| {{CLOUD_PROVIDER}} AI / Foundry | OpenAI, Foundry, AI Search, RAG, Speech, Document Intelligence | `{{cloud_provider}}-ai-architect` | `mkdir -p .skill-locks && touch .skill-locks/{{cloud_provider}}` |
| {{WORKFLOW_ENGINE}} workflow design / architecture | `{{WORKFLOW_ENGINE}}/`, workflow JSON, architecture workflow, orchestration | `{{WORKFLOW_ENGINE}}-workflow-architect` | `mkdir -p .skill-locks && touch .skill-locks/{{WORKFLOW_ENGINE}}` |
| {{WORKFLOW_ENGINE}} node config / expressions | IF/Switch, expressions, validation, property dependencies | `{{WORKFLOW_ENGINE}}-node-expert` | `mkdir -p .skill-locks && touch .skill-locks/{{WORKFLOW_ENGINE}}` |
| {{WORKFLOW_ENGINE}} code nodes | JavaScript/Python dans Code nodes {{WORKFLOW_ENGINE}} | `{{WORKFLOW_ENGINE}}-code-nodes` | `mkdir -p .skill-locks && touch .skill-locks/{{WORKFLOW_ENGINE}}` |
| {{CRM_PLATFORM}} / {{CRM_PLATFORM}} / webhooks | {{CRM_PLATFORM}}, {{CRM_PLATFORM}}, {{CRM_PLATFORM}}, snapshots, workflows, API v2 | `{{crm_platform}}-architect` | `mkdir -p .skill-locks && touch .skill-locks/{{crm_platform}}` |

## Règles de sélection

- Si plusieurs lignes {{CLOUD_PROVIDER}} s'appliquent, choisir le skill le plus spécifique au sujet
- Si la tâche touche du {{SCRIPTING_LANG}} {{PROJECT}}, toujours ajouter `{{project}}-{{scripting_lang}}-script-writer`
- Si la tâche touche {{WORKFLOW_ENGINE}}, choisir exactement un des trois skills {{WORKFLOW_ENGINE}} selon la nature du travail
- Si la tâche mélange plusieurs domaines, charger le minimum nécessaire pour couvrir le scope réel
- Ne jamais charger un skill "au cas où"

## Path-scoped rules — déclencheurs soft

Les rules suivantes sont path-scopées via `paths:` frontmatter et ne se chargent que quand Claude ouvre un fichier matching. Si la tâche implique ces triggers, lire le rule proactivement avant d'agir.

| Trigger | Rule à lire | Action attendue |
|---|---|---|
| Nouveau package Python/Node, nouveau MCP server, nouveau skill externe cloné, nouveau git submodule | `.claude/rules/supply-chain-audit.md` | Invoquer `/supply-chain-audit` avant install |
| Touche `.mcp.json`, `.claude/integrations.md`, un `SKILL.md`, `services-and-access.md`, `tool-routing.md` | `.claude/rules/governance.md` | Co-update canonical files dans le même commit |
| Déplace un dossier de phase (`planned/active/complete`), édite `ROADMAP.md`, `state.yml`, `{{rag_backend}}-registry.json` | `.claude/rules/phase-lifecycle.md` | Respecter le 4-way co-update (git mv + registry + frontmatter + ROADMAP) |
| Triage CVE, édition `dependabot.yml`, `osv-scan.yml`, `patch-management-standard.md` | `.claude/rules/dependency-surveillance.md` | Suivre le flow CVE + SLA par sévérité |
| Prépare un handoff cross-vendor Codex/Gemini, édite un task brief, ou consulte `memory/agents-feedback.md` | `.claude/rules/router-rules.md` | Charger le protocole de handoff avant de déléguer |
| Orchestre des subagents ou une équipe d'agents (prepare-phase, SPARC, review multi-agent) | `.claude/rules/swarm-patterns.md` | Charger les conventions de topologie et anti-drift avant le spawn |
| Crée, ferme, déplace ou audite des todos dans `.planning/todos/` | `.claude/rules/todo-discipline.md` | Utiliser le skill `/todo` plutôt qu'un edit manuel |
| Touche un artefact de phase (`*PLAN*`, `*CONTEXT*`, `*SUMMARY*`, `*VERIFICATION*`, `*RESEARCH*`, `ROADMAP.md`, `STATE.md`) AVANT de proposer un substep GSD (`/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:discuss-phase`) | `.claude/rules/phase-workflow-orchestrator-default.md` | Identifier l'orchestrateur canonique (`/prepare-phase`, closure protocol) et continuer son state machine ; substituer un substep uniquement avec justification explicite |

Ces rules ne bloquent pas mécaniquement (hooks couvrent les domaines {{cloud_provider}}/{{WORKFLOW_ENGINE}}/{{crm_platform}} seulement). C'est de la guidance soft — la discipline est de les lire quand le trigger s'applique.

## Correspondance avec le hook

Deux hooks vérifient les markers :

- `pre-tool-use.sh` — bloque Write/Edit/MultiEdit/Bash sur fichiers de domaine protégé
- `pre-mcp-gate.sh` — bloque les mutations MCP prod ({{WORKFLOW_ENGINE}}-mcp, prod-{{crm_platform}}-mcp, prod-{{crm_platform}}-care-mcp)

Markers vérifiés : `{{cloud_provider}}`, `{{WORKFLOW_ENGINE}}`, `{{crm_platform}}`

Les lectures MCP prod et tous les appels MCP dev ne sont pas bloqués.

Toute évolution de ce fichier qui change les domaines ou markers doit être reflétée dans :

- `.claude/hooks/pre-tool-use.sh`
- `.claude/hooks/pre-mcp-gate.sh`
- `.claude/settings.json` (PreToolUse matchers)

## Règle de maintenance

Mettre à jour ce fichier dans le même commit si :

- un nouveau domaine protégé est ajouté
- un skill requis change
- un marker change
- le hook `pre-tool-use.sh` ou `pre-mcp-gate.sh` change sa logique de contrôle

## Ce qui ne va pas ici

Ne pas mettre dans ce fichier :

- inventaire des MCP
- détails d'accès serveurs
- stack du projet
- workflows détaillés
- règles de routing modèles / executors

Ces informations vivent ailleurs :

- intégrations actives : `.claude/integrations.md`
- accès / services / endpoints : `docs/codebase/services-and-access.md`
- caps / pagination / anti-patterns MCP : `.claude/rules/tool-routing.md`
- routing modèles / executors : `.claude/rules/router-rules.md`
